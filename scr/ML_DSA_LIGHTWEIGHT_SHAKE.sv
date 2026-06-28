module ML_DSA_LIGHTWEIGHT_SHAKE (
    input  wire        iClk,
    input  wire        iRst_n,
    input  wire        iStart,         
    input  wire        iMode,          // 0: SHAKE128 (Rate 21) | 1: SHAKE256 (Rate 17)
    
    // Input (Absorb)
    input  wire [63:0] iData,
    input  wire        iValid,
    input  wire        iLast,
    input  wire        iLast_16bit,
    output wire        oReady,
    
    // Output (XOF Squeeze)
    input  wire        iSqueeze_En,
    output wire [63:0] oHash_Word,
    output wire        oHash_Valid,
    output wire        oDone
);

    // FSM STATE
    localparam ST_IDLE       = 3'd0;
    localparam ST_ABSORB     = 3'd1;
    localparam ST_PAD_ONLY   = 3'd2;
    localparam ST_PROCESS    = 3'd3;
    localparam ST_SQUEEZE    = 3'd4;

    reg [2:0] state;
    reg [4:0] cycle_cnt, round_cnt, iword;
    reg       EndMessage_Flag, RegPad;

    wire [4:0] rate_lanes = (iMode == 1'b0) ? 5'd21 : 5'd17;
    
    assign oReady = (state == ST_ABSORB) && (cycle_cnt < rate_lanes) && !EndMessage_Flag;
    wire iReady = iValid && oReady; // DATA INPUT VALID TRANSMIT
    
    wire shift_active = (state == ST_ABSORB && (iReady || EndMessage_Flag || cycle_cnt >= rate_lanes)) || 
                        (state == ST_PAD_ONLY) || 
                        (state == ST_SQUEEZE && (iSqueeze_En || cycle_cnt >= rate_lanes));

    // FORMAT DATA INPUT (LITTLE ENDIAN)
    wire [63:0] data_swapped = {
        iData[7:0], iData[15:8], iData[23:16], iData[31:24], 
        iData[39:32], iData[47:40], iData[55:48], iData[63:56]
    };

    // PAD10*1
    reg [63:0] inject_word;
    always @(*) begin
        inject_word = 64'h0; // CAPCITY
        
        if (state == ST_ABSORB && cycle_cnt < rate_lanes) begin
            if (!EndMessage_Flag && iReady) begin
                if (iLast && iLast_16bit) 
                    // 2 BYTE MESSAGE + 6 BYTE PAD
                    inject_word = {40'h00, 8'h1F, iData[7:0], iData[15:8]}; 
                else 
                    inject_word = data_swapped; // 8 BYTE MESSAGE
            end 
            else if (EndMessage_Flag && cycle_cnt == iword) begin
                inject_word[7:0] = 8'h1F; // SUFFIX PAD
            end
            
            if (cycle_cnt == (rate_lanes - 5'd1)) begin
                if (!EndMessage_Flag && iReady && iLast && !iLast_16bit) begin
                    // ENDING PAD
                end else if (EndMessage_Flag || (iReady && iLast)) begin
                    inject_word[63:56] = inject_word[63:56] | 8'h80;
                end
            end
        end 
        else if (state == ST_PAD_ONLY && cycle_cnt < rate_lanes) begin
            if (cycle_cnt == 0) inject_word[7:0] = 8'h1F;
            if (cycle_cnt == (rate_lanes - 5'd1)) inject_word[63:56] = 8'h80;
        end
    end

    // STATE SPONGE: 1600 bit = R + C
    reg [63:0] S [0:24];
    wire [1599:0] State_Sponge;
    assign State_Sponge = {
        S[24], S[23], S[22], S[21], S[20],
        S[19], S[18], S[17], S[16], S[15],
        S[14], S[13], S[12], S[11], S[10],
        S[9],  S[8],  S[7],  S[6],  S[5],
        S[4],  S[3],  S[2],  S[1],  S[0]
    };

    wire [1599:0] round_out;
    wire [63:0]   RC;

    round_constant u_rc (
        .round_index(round_cnt),
        .round_constant_out(RC)
    );

    keccak_round u_keccak (
        .state_in(State_Sponge),
        .round_constant_in(RC),
        .state_out(round_out)
    );


    // FSM
    always @(posedge iClk or negedge iRst_n) begin
        if (!iRst_n | iStart) begin
            state <= iStart ? ST_ABSORB : ST_IDLE;
            cycle_cnt <= 0; round_cnt <= 0; // RESET COUNTER
            EndMessage_Flag <= 0; iword <= 0; RegPad <= 0;  // RESET FLAG

            //RESET STATE
            S[0]  <= 0; S[1]  <= 0; S[2]  <= 0; S[3]  <= 0; S[4]  <= 0; S[5]  <= 0; 
            S[6]  <= 0; S[7]  <= 0; S[8]  <= 0; S[9]  <= 0; S[10] <= 0; S[11] <= 0; 
            S[12] <= 0; S[13] <= 0; S[14] <= 0; S[15] <= 0; S[16] <= 0; S[17] <= 0; 
            S[18] <= 0; S[19] <= 0; S[20] <= 0; S[21] <= 0; S[22] <= 0; S[23] <= 0;  
            S[24] <= 0;

        end 
         else begin
            // FSM MUX
            case (state)
                ST_IDLE:       state <= ST_IDLE;
                ST_ABSORB:     if (shift_active && cycle_cnt == 24) state <= ST_PROCESS;
                ST_PAD_ONLY:   if (cycle_cnt == 24) state <= ST_PROCESS;
                ST_PROCESS:    if (round_cnt == 23) state <= (!EndMessage_Flag) ? ST_ABSORB : (RegPad ? ST_PAD_ONLY : ST_SQUEEZE);
                ST_SQUEEZE:    if (shift_active && cycle_cnt == 24) state <= ST_PROCESS;
            endcase

            if (state == ST_PROCESS && round_cnt == 23) round_cnt <= 0;
                else if (state == ST_PROCESS) round_cnt <= round_cnt + 1'b1;
                    else round_cnt <= 0;

            if (state == ST_PROCESS && round_cnt == 23) cycle_cnt <= 0; 
                else if (shift_active) cycle_cnt <= (cycle_cnt == 24) ? 5'd0 : cycle_cnt + 1'b1;

            if (state == ST_ABSORB && iReady && iLast && !EndMessage_Flag) begin
                EndMessage_Flag <= 1'b1;
                iword <= cycle_cnt + (!iLast_16bit ? 1 : 0);
                if (cycle_cnt == (rate_lanes - 5'd1) && !iLast_16bit) RegPad <= 1'b1;
            end
            if (state == ST_PAD_ONLY && cycle_cnt == 24) RegPad <= 0;

            if (state == ST_PROCESS) begin
                //DATAPATH -> STATE KECCAK_F
                S[0]  <= round_out[63:0];      S[1]  <= round_out[127:64];    S[2]  <= round_out[191:128];
                S[3]  <= round_out[255:192];   S[4]  <= round_out[319:256];   S[5]  <= round_out[383:320];
                S[6]  <= round_out[447:384];   S[7]  <= round_out[511:448];   S[8]  <= round_out[575:512];
                S[9]  <= round_out[639:576];   S[10] <= round_out[703:640];   S[11] <= round_out[767:704];
                S[12] <= round_out[831:768];   S[13] <= round_out[895:832];   S[14] <= round_out[959:896];
                S[15] <= round_out[1023:960];  S[16] <= round_out[1087:1024]; S[17] <= round_out[1151:1088];
                S[18] <= round_out[1215:1152]; S[19] <= round_out[1279:1216]; S[20] <= round_out[1343:1280];
                S[21] <= round_out[1407:1344]; S[22] <= round_out[1471:1408]; S[23] <= round_out[1535:1472];
                S[24] <= round_out[1599:1536];

              

            end else if (shift_active) begin
        
                //SHIFT BLOCK
                S[0]  <=  S[1];  S[1]  <= S[2];  S[2]  <= S[3];   S[3]  <= S[4];  S[4]  <= S[5]; 
                S[5]  <=  S[6];  S[6]  <= S[7];  S[7]  <= S[8];   S[8]  <= S[9];  S[9]  <= S[10];
                S[10] <=  S[11]; S[11] <= S[12]; S[12] <= S[13];  S[13] <= S[14]; S[14] <= S[15]; 
                S[15] <=  S[16]; S[16] <= S[17]; S[17] <=  S[18]; S[18] <= S[19]; S[19] <= S[20]; 
                S[20] <=  S[21];  S[21] <=  S[22]; S[22] <= S[23]; S[23] <= S[24]; 

                if (state == ST_ABSORB || state == ST_PAD_ONLY)
                    S[24] <= S[0] ^ inject_word; //ABSORB
                else
                    S[24] <= S[0]; //SQUEEZE
            end
        end
    end

    // FORMAT HASH OUTPUT (SQUEEZE) (BIG ENDIAN)
    assign oHash_Word = {
        S[0][7:0],   S[0][15:8],  S[0][23:16], S[0][31:24], 
        S[0][39:32], S[0][47:40], S[0][55:48], S[0][63:56]
    };
    
    // FLAG OUTPUT VALID 
    assign oHash_Valid = (state == ST_SQUEEZE) && (cycle_cnt < rate_lanes) && iSqueeze_En;
    assign oDone       = (state == ST_SQUEEZE);

endmodule

//KECCAK_f 
module keccak_round (
    input  wire [1599:0] state_in,
    input  wire [63:0]   round_constant_in,
    output wire [1599:0] state_out
);
    wire [1599:0] theta_out, rho_pi_out, chi_out;
    theta  u_theta  (.state_in(state_in),      .state_out(theta_out));
    rho_pi u_rho_pi (.state_in(theta_out),     .state_out(rho_pi_out));
    chi    u_chi    (.state_in(rho_pi_out),    .state_out(chi_out));
    iota   u_iota   (.state_in(chi_out),       .round_constant_in(round_constant_in), .state_out(state_out));
endmodule

module theta (
    input  wire [1599:0] state_in,
    output wire [1599:0] state_out
);
    wire [63:0] C0, C1, C2, C3, C4;
    wire [63:0] D0, D1, D2, D3, D4;

    assign C0 = state_in[63:0]     ^ state_in[383:320] ^ state_in[703:640]  ^ state_in[1023:960]  ^ state_in[1343:1280];
    assign C1 = state_in[127:64]   ^ state_in[447:384] ^ state_in[767:704]  ^ state_in[1087:1024] ^ state_in[1407:1344];
    assign C2 = state_in[191:128]  ^ state_in[511:448] ^ state_in[831:768]  ^ state_in[1151:1088] ^ state_in[1471:1408];
    assign C3 = state_in[255:192]  ^ state_in[575:512] ^ state_in[895:832]  ^ state_in[1215:1152] ^ state_in[1535:1472];
    assign C4 = state_in[319:256]  ^ state_in[639:576] ^ state_in[959:896]  ^ state_in[1279:1216] ^ state_in[1599:1536];

    assign D0 = C4 ^ {C1[62:0], C1[63]};
    assign D1 = C0 ^ {C2[62:0], C2[63]};
    assign D2 = C1 ^ {C3[62:0], C3[63]};
    assign D3 = C2 ^ {C4[62:0], C4[63]};
    assign D4 = C3 ^ {C0[62:0], C0[63]};

    assign state_out[63:0]      = state_in[63:0]      ^ D0;
    assign state_out[127:64]    = state_in[127:64]    ^ D1;
    assign state_out[191:128]   = state_in[191:128]   ^ D2;
    assign state_out[255:192]   = state_in[255:192]   ^ D3;
    assign state_out[319:256]   = state_in[319:256]   ^ D4;
    assign state_out[383:320]   = state_in[383:320]   ^ D0;
    assign state_out[447:384]   = state_in[447:384]   ^ D1;
    assign state_out[511:448]   = state_in[511:448]   ^ D2;
    assign state_out[575:512]   = state_in[575:512]   ^ D3;
    assign state_out[639:576]   = state_in[639:576]   ^ D4;
    assign state_out[703:640]   = state_in[703:640]   ^ D0;
    assign state_out[767:704]   = state_in[767:704]   ^ D1;
    assign state_out[831:768]   = state_in[831:768]   ^ D2;
    assign state_out[895:832]   = state_in[895:832]   ^ D3;
    assign state_out[959:896]   = state_in[959:896]   ^ D4;
    assign state_out[1023:960]  = state_in[1023:960]  ^ D0;
    assign state_out[1087:1024] = state_in[1087:1024] ^ D1;
    assign state_out[1151:1088] = state_in[1151:1088] ^ D2;
    assign state_out[1215:1152] = state_in[1215:1152] ^ D3;
    assign state_out[1279:1216] = state_in[1279:1216] ^ D4;
    assign state_out[1343:1280] = state_in[1343:1280] ^ D0;
    assign state_out[1407:1344] = state_in[1407:1344] ^ D1;
    assign state_out[1471:1408] = state_in[1471:1408] ^ D2;
    assign state_out[1535:1472] = state_in[1535:1472] ^ D3;
    assign state_out[1599:1536] = state_in[1599:1536] ^ D4;
endmodule

module rho_pi (
    input  wire [1599:0] state_in,
    output wire [1599:0] state_out
);
    wire [1599:0] rho_out;
    assign rho_out[63:0]      = state_in[63:0];
    assign rho_out[127:64]    = {state_in[126:64],    state_in[127]};
    assign rho_out[191:128]   = {state_in[129:128],   state_in[191:130]};
    assign rho_out[255:192]   = {state_in[227:192],   state_in[255:228]};
    assign rho_out[319:256]   = {state_in[292:256],   state_in[319:293]};
    assign rho_out[383:320]   = {state_in[347:320],   state_in[383:348]};
    assign rho_out[447:384]   = {state_in[403:384],   state_in[447:404]};
    assign rho_out[511:448]   = {state_in[505:448],   state_in[511:506]};
    assign rho_out[575:512]   = {state_in[520:512],   state_in[575:521]};
    assign rho_out[639:576]   = {state_in[619:576],   state_in[639:620]};
    assign rho_out[703:640]   = {state_in[700:640],   state_in[703:701]};
    assign rho_out[767:704]   = {state_in[757:704],   state_in[767:758]};
    assign rho_out[831:768]   = {state_in[788:768],   state_in[831:789]};
    assign rho_out[895:832]   = {state_in[870:832],   state_in[895:871]};
    assign rho_out[959:896]   = {state_in[920:896],   state_in[959:921]};
    assign rho_out[1023:960]  = {state_in[982:960],   state_in[1023:983]};
    assign rho_out[1087:1024] = {state_in[1042:1024], state_in[1087:1043]};
    assign rho_out[1151:1088] = {state_in[1136:1088], state_in[1151:1137]};
    assign rho_out[1215:1152] = {state_in[1194:1152], state_in[1215:1195]};
    assign rho_out[1279:1216] = {state_in[1271:1216], state_in[1279:1272]};
    assign rho_out[1343:1280] = {state_in[1325:1280], state_in[1343:1326]};
    assign rho_out[1407:1344] = {state_in[1405:1344], state_in[1407:1406]};
    assign rho_out[1471:1408] = {state_in[1410:1408], state_in[1471:1411]};
    assign rho_out[1535:1472] = {state_in[1479:1472], state_in[1535:1480]};
    assign rho_out[1599:1536] = {state_in[1585:1536], state_in[1599:1586]};

    assign state_out[63:0]      = rho_out[63:0];
    assign state_out[127:64]    = rho_out[447:384];
    assign state_out[191:128]   = rho_out[831:768];
    assign state_out[255:192]   = rho_out[1215:1152];
    assign state_out[319:256]   = rho_out[1599:1536];
    assign state_out[383:320]   = rho_out[255:192];
    assign state_out[447:384]   = rho_out[639:576];
    assign state_out[511:448]   = rho_out[703:640];
    assign state_out[575:512]   = rho_out[1087:1024];
    assign state_out[639:576]   = rho_out[1471:1408];
    assign state_out[703:640]   = rho_out[127:64];
    assign state_out[767:704]   = rho_out[511:448];
    assign state_out[831:768]   = rho_out[895:832];
    assign state_out[895:832]   = rho_out[1279:1216];
    assign state_out[959:896]   = rho_out[1343:1280];
    assign state_out[1023:960]  = rho_out[319:256];
    assign state_out[1087:1024] = rho_out[383:320];
    assign state_out[1151:1088] = rho_out[767:704];
    assign state_out[1215:1152] = rho_out[1151:1088];
    assign state_out[1279:1216] = rho_out[1535:1472];
    assign state_out[1343:1280] = rho_out[191:128];
    assign state_out[1407:1344] = rho_out[575:512];
    assign state_out[1471:1408] = rho_out[959:896];
    assign state_out[1535:1472] = rho_out[1023:960];
    assign state_out[1599:1536] = rho_out[1407:1344];
endmodule

module chi (
    input  wire [1599:0] state_in,
    output wire [1599:0] state_out
);
    assign state_out[63:0]      = state_in[63:0]      ^ (~state_in[127:64]    & state_in[191:128]);
    assign state_out[127:64]    = state_in[127:64]    ^ (~state_in[191:128]   & state_in[255:192]);
    assign state_out[191:128]   = state_in[191:128]   ^ (~state_in[255:192]   & state_in[319:256]);
    assign state_out[255:192]   = state_in[255:192]   ^ (~state_in[319:256]   & state_in[63:0]);
    assign state_out[319:256]   = state_in[319:256]   ^ (~state_in[63:0]      & state_in[127:64]);
    assign state_out[383:320]   = state_in[383:320]   ^ (~state_in[447:384]   & state_in[511:448]);
    assign state_out[447:384]   = state_in[447:384]   ^ (~state_in[511:448]   & state_in[575:512]);
    assign state_out[511:448]   = state_in[511:448]   ^ (~state_in[575:512]   & state_in[639:576]);
    assign state_out[575:512]   = state_in[575:512]   ^ (~state_in[639:576]   & state_in[383:320]);
    assign state_out[639:576]   = state_in[639:576]   ^ (~state_in[383:320]   & state_in[447:384]);
    assign state_out[703:640]   = state_in[703:640]   ^ (~state_in[767:704]   & state_in[831:768]);
    assign state_out[767:704]   = state_in[767:704]   ^ (~state_in[831:768]   & state_in[895:832]);
    assign state_out[831:768]   = state_in[831:768]   ^ (~state_in[895:832]   & state_in[959:896]);
    assign state_out[895:832]   = state_in[895:832]   ^ (~state_in[959:896]   & state_in[703:640]);
    assign state_out[959:896]   = state_in[959:896]   ^ (~state_in[703:640]   & state_in[767:704]);
    assign state_out[1023:960]  = state_in[1023:960]  ^ (~state_in[1087:1024] & state_in[1151:1088]);
    assign state_out[1087:1024] = state_in[1087:1024] ^ (~state_in[1151:1088] & state_in[1215:1152]);
    assign state_out[1151:1088] = state_in[1151:1088] ^ (~state_in[1215:1152] & state_in[1279:1216]);
    assign state_out[1215:1152] = state_in[1215:1152] ^ (~state_in[1279:1216] & state_in[1023:960]);
    assign state_out[1279:1216] = state_in[1279:1216] ^ (~state_in[1023:960]  & state_in[1087:1024]);
    assign state_out[1343:1280] = state_in[1343:1280] ^ (~state_in[1407:1344] & state_in[1471:1408]);
    assign state_out[1407:1344] = state_in[1407:1344] ^ (~state_in[1471:1408] & state_in[1535:1472]);
    assign state_out[1471:1408] = state_in[1471:1408] ^ (~state_in[1535:1472] & state_in[1599:1536]);
    assign state_out[1535:1472] = state_in[1535:1472] ^ (~state_in[1599:1536] & state_in[1343:1280]);
    assign state_out[1599:1536] = state_in[1599:1536] ^ (~state_in[1343:1280] & state_in[1407:1344]);
endmodule

module iota (
    input  wire [1599:0] state_in,
    input  wire [63:0]   round_constant_in,
    output wire [1599:0] state_out
);
    assign state_out[63:0]    = state_in[63:0] ^ round_constant_in;
    assign state_out[1599:64] = state_in[1599:64];
endmodule

module round_constant (
    input  wire [4:0]  round_index,
    output reg  [63:0] round_constant_out
);
    always @(*) begin
        case (round_index)
            5'd0 : round_constant_out = 64'h0000000000000001; 5'd1 : round_constant_out = 64'h0000000000008082; 
            5'd2 : round_constant_out = 64'h800000000000808A; 5'd3 : round_constant_out = 64'h8000000080008000;
            5'd4 : round_constant_out = 64'h000000000000808B; 5'd5 : round_constant_out = 64'h0000000080000001; 
            5'd6 : round_constant_out = 64'h8000000080008081; 5'd7 : round_constant_out = 64'h8000000000008009;
            5'd8 : round_constant_out = 64'h000000000000008A; 5'd9 : round_constant_out = 64'h0000000000000088; 
            5'd10: round_constant_out = 64'h0000000080008009; 5'd11: round_constant_out = 64'h000000008000000A;
            5'd12: round_constant_out = 64'h000000008000808B; 5'd13: round_constant_out = 64'h800000000000008B; 
            5'd14: round_constant_out = 64'h8000000000008089; 5'd15: round_constant_out = 64'h8000000000008003;
            5'd16: round_constant_out = 64'h8000000000008002; 5'd17: round_constant_out = 64'h8000000000000080; 
            5'd18: round_constant_out = 64'h000000000000800A; 5'd19: round_constant_out = 64'h800000008000000A;
            5'd20: round_constant_out = 64'h8000000080008081; 5'd21: round_constant_out = 64'h8000000000008080; 
            5'd22: round_constant_out = 64'h0000000080000001; 5'd23: round_constant_out = 64'h8000000080008008;
            default: round_constant_out = 64'h0000000000000000;
        endcase
    end
endmodule