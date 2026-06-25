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
    integer i;
    always @(posedge iClk or negedge iRst_n) begin
        if (!iRst_n) begin
            state <= ST_IDLE;
            cycle_cnt <= 0; round_cnt <= 0; // RESET COUNTER
            EndMessage_Flag <= 0; iword <= 0; RegPad <= 0;  // RESET FLAG

            //RESET STATE
            S[0]  <= 0; S[1]  <= 0; S[2]  <= 0; S[3]  <= 0; S[4]  <= 0; S[5]  <= 0; 
            S[6]  <= 0; S[7]  <= 0; S[8]  <= 0; S[9]  <= 0; S[10] <= 0; S[11] <= 0; 
            S[12] <= 0; S[13] <= 0; S[14] <= 0; S[15] <= 0; S[16] <= 0; S[17] <= 0; 
            S[18] <= 0; S[19] <= 0; S[20] <= 0; S[21] <= 0; S[22] <= 0; S[23] <= 0;  
            S[24] <= 0;

        end else if (iStart) begin 
            state <= ST_ABSORB; 
            cycle_cnt <= 0; round_cnt <= 0;  // RESET COUNTER
            EndMessage_Flag <= 0; iword <= 0; RegPad <= 0; // RESET FLAG
            
            // CLEAR PREVIOS STATE (PREVIOS MESSAGE HASH)
            S[0]  <= 0; S[1]  <= 0; S[2]  <= 0; S[3]  <= 0; S[4]  <= 0; S[5]  <= 0; 
            S[6]  <= 0; S[7]  <= 0; S[8]  <= 0; S[9]  <= 0; S[10] <= 0; S[11] <= 0; 
            S[12] <= 0; S[13] <= 0; S[14] <= 0; S[15] <= 0; S[16] <= 0; S[17] <= 0; 
            S[18] <= 0; S[19] <= 0; S[20] <= 0; S[21] <= 0; S[22] <= 0; S[23] <= 0; 
            S[24] <= 0;
        end else begin
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


`timescale 1ns / 1ps

module tb_ML_DSA_LIGHTWAVE_SHAKE();

    reg         iClk;
    reg         iRst_n;
    reg         iStart;
    reg         iMode;  
    
    reg [63:0]  iData;
    reg         iValid;
    reg         iLast;
    reg         iLast_16bit;
    wire        oReady;
    
    reg         iSqueeze_En;
    wire [63:0] oHash;
    wire        oHash_Valid;
    wire        oDone;

    ML_DSA_LIGHTWEIGHT_SHAKE uut (
        .iClk(iClk),
        .iRst_n(iRst_n),
        .iStart(iStart),
        .iMode(iMode),
        .iData(iData),
        .iValid(iValid),
        .iLast(iLast),
        .iLast_16bit(iLast_16bit),
        .oReady(oReady),
        .iSqueeze_En(iSqueeze_En), 
        .oHash_Word(oHash),
        .oHash_Valid(oHash_Valid),
        .oDone(oDone)
    );

    initial begin
        iClk = 0;
        forever #5 iClk = ~iClk; 
    end

    integer out_idx;
    reg [1087:0] digest_out;

    always @(posedge iClk) begin
        if (!iRst_n || iStart) begin
            out_idx <= 0;
            digest_out <= 1088'h0;
        end else if (oHash_Valid) begin
            case (out_idx)
                0:  digest_out[1087:1024] <= oHash; 
                1:  digest_out[1023:960]  <= oHash; 
                2:  digest_out[959:896]   <= oHash;
                3:  digest_out[895:832]   <= oHash;
                4:  digest_out[831:768]   <= oHash;
                5:  digest_out[767:704]   <= oHash;
                6:  digest_out[703:640]   <= oHash;
                7:  digest_out[639:576]   <= oHash;
                8:  digest_out[575:512]   <= oHash;
                9:  digest_out[511:448]   <= oHash;
                10: digest_out[447:384]   <= oHash;
                11: digest_out[383:320]   <= oHash;
                12: digest_out[319:256]   <= oHash;
                13: digest_out[255:192]   <= oHash;
                14: digest_out[191:128]   <= oHash;
                15: digest_out[127:64]    <= oHash;
                16: digest_out[63:0]      <= oHash;
            endcase
            out_idx <= out_idx + 1;
        end
    end

    task start_hash;
        begin
            @(negedge iClk);
            iStart = 1'b1;
            @(negedge iClk);
            iStart = 1'b0;
        end
    endtask

    reg mute_log = 0; 

    task send_word;
        input [63:0] t_data;
        input        t_is_last;
        input        t_is_16bit;
        begin
            if (!mute_log)
                $display("Data: %016X | Last: %b", t_data, t_is_last);

            @(negedge iClk);
            iValid      = 1'b1;
            iData       = t_data;
            iLast       = t_is_last;
            iLast_16bit = t_is_16bit;
            
            wait(oReady == 1'b1);
            @(posedge iClk); 
            
            @(negedge iClk);
            iValid      = 1'b0;
            iLast       = 1'b0;
            iLast_16bit = 1'b0;
        end
    endtask

    task check_hash;
        input [1087:0] expected_hash;
        begin
            wait(oDone == 1'b1);
            
            @(negedge iClk);
            iSqueeze_En = 1'b1;
            
            wait(out_idx == 17);
            
            @(negedge iClk);
            iSqueeze_En = 1'b0;
            
            @(posedge iClk);
            $display("   -------------------------------------------------------------------------");
            $display("   [Digest Out]    %X", digest_out);
            $display("   [Expected Hash] %X", expected_hash);
            
            if (digest_out === expected_hash)
                $display("========================================> PASS\n");
            else
                $display("========================================> FAILED\n");
        end
    endtask

    integer w;

    initial begin
        iRst_n = 0; iStart = 0;
        iValid = 0; iLast = 0; iLast_16bit = 0; iData = 0; iSqueeze_En = 0;
        
        #100;
        iRst_n = 1;
        #20;

        iStart = 1;
        $display("TEST 1: KeyGen - Expand Seed (32 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 3; w = w + 1) begin
            send_word(64'h1111111111111111, 1'b0, 1'b0);
        end
        send_word(64'h1111111111111111, 1'b1, 1'b0); // Word 4 (Last)
        check_hash(1088'hFFBBAE4F351B619460FA09EAED2696331EBA5800A356B06A87D92BB3694802003193104C76C4213377ECFD345B79639B56D2F9D7F52C36F81DD0F8F9029244A1AFD9948D5FFDACC37F573742EA32C04AE97AEA307658B56A3B5C3157A0343462B4676D285A676F2351E094B04DB0F509386EBC47FE6E5D1A88ED640F5AAD1D9046C1FAA3B3C8169A); 

        $display("TEST 2: SampleInBall (64 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 7; w = w + 1) begin
            send_word(64'h2222222222222222, 1'b0, 1'b0);
        end
        send_word(64'h2222222222222222, 1'b1, 1'b0); // Word 8 (Last)
        check_hash(1088'h18CFCA11E00FFD3F4FA40ACA2ADFD503B60575B68DF6CC48FCEFF3623B8A7DA1BDD2B1F72AACC2A89C8E6F1CF13FA81790B8A15054C1C1C87690868B40DCF1739B7DAA5F33FC5F84A392916E45201C6F3A74C6B596FC5ACE9EB379D45CC131319CEE67C52F553C20DA59602738D304EA57B93939E95F0F93633C3A2F8644E44C72435F298B50E27E);

        $display("TEST 3: ExpandS / ExpandMask (66 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 8; w = w + 1) begin
            send_word(64'h3333333333333333, 1'b0, 1'b0);
        end
        send_word(64'h0000000000003333, 1'b1, 1'b1); // Word 9 (Last, Dư 16bit)
        check_hash(1088'h9A21A347990FA981E315DBD5505D5ECCD56E3D1579451B2520B9247EC7BC886B34F3339E480E839627CA110EBF37E441C2E8CA7481BF1C184DDD1A939FBCA282E8C5500555D7AD09628AAB57E7B6074367B25E41A885067C93D3CFAB8A0569E1BB182CB4C4D5F65222BBFD7B0653919A25E2D28F950CE6365CB2B81048E12435E0A31D7F7B1FC13F);

        $display("TEST 4: Sign - secret seed (128 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 0;
        for (w = 0; w < 15; w = w + 1) begin
            send_word(64'h4444444444444444, 1'b0, 1'b0);
        end
        send_word(64'h4444444444444444, 1'b1, 1'b0); // Word 16 (Last)
        check_hash(1088'h44352005A50F864E1BB8672F735EDBDE3356C10FED4C11E59A771510146FDFEA93546152FA392CA4FE6E3C94958232111F76CC4DF75B41E291C9678AE752324BD9CC83EF3018BEF0BA33B87AFEB37E845636A78583EEB8E53B07A6046525DE3BA21EBF26FF2D366F3990D14530286A995C9A8DE5BD0DC892B0D3C4EA4BD45F6B7A8890AB9289446C); 

        $display("TEST 5: Sign/Verify -  (1088 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 1; 
        for (w = 0; w < 135; w = w + 1) begin 
            send_word(64'h5555555555555555, 1'b0, 1'b0);
        end
        mute_log = 0;
        send_word(64'h5555555555555555, 1'b1, 1'b0); // Word 136 (Last)
        check_hash(1088'h156C79294F216430B040A698FBD663AB03F9CDDF6D5FD508529D754CBBEAF45442463E7C69C3CB16669952D6B9C45AEDBD02F993696D4BF2B0247D252947AE60794E37F3B0EC1CB562371169BD822F7EF9422F7853B4AC0DF2A802E6A1989E829EAED710F96B4D76E1725768EFD479058A235F7CAC25224BEAA40A40B0BF5F46C82BDE7DFAB50B97);

        $display("TEST 6: KeyGen/Verify - Public Key ML-DSA-87 (2592 Byte)");
        iMode = 1'b1;
        start_hash();
        mute_log = 1; 
        for (w = 0; w < 323; w = w + 1) begin 
            send_word(64'h6666666666666666, 1'b0, 1'b0);
        end
        mute_log = 0;
        send_word(64'h6666666666666666, 1'b1, 1'b0); // Word 324 (Last)
        check_hash(1088'h927E9E51547422411EE7A34C6951AECD53E108AEA9D78709BEE6D09FBD58E4FAF9EDBF059CE957C86B5641E0E1D4BC34BB501C49A8D3DE5B2E3F5EB67296A9DA0B731B98EE84B45687C6C8E85876B4AF8A00B499F9FFBDA48EF56F9053463C6D2FF8FAC4A27BE328FAF4DBB45DB202AC5770D85C2E7D7AE0D93444F0B74330266DA0424008EB81C0); 

        $display("TEST 7: ExpandA (RejNTTPoly) - SHAKE128 (34 Byte)");
        iMode = 1'b0; // SHAKE128
        start_hash();
        mute_log = 0;
        for (w = 0; w < 4; w = w + 1) begin
            send_word(64'h7777777777777777, 1'b0, 1'b0);
        end
        send_word(64'h0000000000007777, 1'b1, 1'b1);
        check_hash(1088'h1B1F4D2F9DAAC7637A66337BFB013B0B3BB7A152FD92E40A9FB4F668BC0323815084B7A9783EA5A5E87F49C2C1182CBE8B354FF367C63C7EBD147589E5E6B4204FFF0BCF0F84890852CD90234656FA9BFD67FA6F5ADD6883205F8816612E81C8D0D788A60E97AD85BB55F089B86CF817C6E6620A442E2801084D332F07875909536EA9DD1496A2DC);

        // =============================================================
        $display("=== TEST 8: 64 Byte Tròn Block ZEROS ===");
        iMode = 1'b1; 
        start_hash();
        mute_log = 0;
        for (w = 0; w < 7; w = w + 1) begin
            send_word(64'h0, 1'b0, 1'b0);
        end
        send_word(64'h0, 1'b1, 1'b0);
        check_hash(1088'h7EA5F2EA9E9487DE4753918BBF5308EB91FA641889236C55D708ECB4D9666A3608D79DAE85E23E2BEB312FEDB521E82CF1A233ADCD4A9C276C748BECD595C409C572EEE787DB91A414980911B5AF6CEDC51135F12BD074FFFC140F68698CA2780671B2416C365A385ADCFED1F5FE78FE9E753BFFA22875DEC51D81F86AE41DA5A120243B1BFE9077);

        #500;
        $finish;
    end

    initial begin
        $dumpfile("tb_ML_DSA_LIGHTWAVE_SHAKE.vcd");
        $dumpvars(0, tb_ML_DSA_LIGHTWAVE_SHAKE);
    end

endmodule
