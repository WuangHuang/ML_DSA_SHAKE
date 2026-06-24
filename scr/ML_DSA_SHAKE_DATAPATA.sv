module ML_DSA_SHAKE_DATAPATH (
    input  wire          iclk, 
    input  wire          rst_n, 
    input  wire          FlatStart,
    input  wire [2:0]    FSMstate,
    input  wire          shift_active,
    input  wire [63:0]   iword,
    input  wire [1599:0] oRound,
    
    output wire [1599:0] oState,
    output wire [63:0]   oHash
);
    localparam IDLE=3'd0, ABSORB_SHIFT=3'd1, PAD_ONLY_BLK=3'd2, PROCESS=3'd3;
    
    reg [63:0] S [0:24];
    assign oState = {
        S[0],  S[1],  S[2],  S[3],  S[4],
        S[5],  S[6],  S[7],  S[8],  S[9],
        S[10], S[11], S[12], S[13], S[14],
        S[15], S[16], S[17], S[18], S[19],
        S[20], S[21], S[22], S[23], S[24]
    };

    always @(posedge iclk or negedge rst_n) begin
        if (!rst_n) begin
            // RESET STATE
            S[0]  <= 64'h0; S[1]  <= 64'h0; S[2]  <= 64'h0; S[3]  <= 64'h0; S[4]  <= 64'h0;
            S[5]  <= 64'h0; S[6]  <= 64'h0; S[7]  <= 64'h0; S[8]  <= 64'h0; S[9]  <= 64'h0;
            S[10] <= 64'h0; S[11] <= 64'h0; S[12] <= 64'h0; S[13] <= 64'h0; S[14] <= 64'h0;
            S[15] <= 64'h0; S[16] <= 64'h0; S[17] <= 64'h0; S[18] <= 64'h0; S[19] <= 64'h0;
            S[20] <= 64'h0; S[21] <= 64'h0; S[22] <= 64'h0; S[23] <= 64'h0; S[24] <= 64'h0;
            
        end else if (FlatStart) begin
            // CLEAR PREVIOUS STATE
            S[0]  <= 64'h0; S[1]  <= 64'h0; S[2]  <= 64'h0; S[3]  <= 64'h0; S[4]  <= 64'h0;
            S[5]  <= 64'h0; S[6]  <= 64'h0; S[7]  <= 64'h0; S[8]  <= 64'h0; S[9]  <= 64'h0;
            S[10] <= 64'h0; S[11] <= 64'h0; S[12] <= 64'h0; S[13] <= 64'h0; S[14] <= 64'h0;
            S[15] <= 64'h0; S[16] <= 64'h0; S[17] <= 64'h0; S[18] <= 64'h0; S[19] <= 64'h0;
            S[20] <= 64'h0; S[21] <= 64'h0; S[22] <= 64'h0; S[23] <= 64'h0; S[24] <= 64'h0;

        end else begin
            
            if (FSMstate == PROCESS) begin
                // KECCAK_STATE -> DATAPATH_STATE
                S[0]  <= oRound[1599:1536]; S[1]  <= oRound[1535:1472]; S[2]  <= oRound[1471:1408];
                S[3]  <= oRound[1407:1344]; S[4]  <= oRound[1343:1280]; S[5]  <= oRound[1279:1216];
                S[6]  <= oRound[1215:1152]; S[7]  <= oRound[1151:1088]; S[8]  <= oRound[1087:1024];
                S[9]  <= oRound[1023:960];  S[10] <= oRound[959:896];   S[11] <= oRound[895:832];
                S[12] <= oRound[831:768];   S[13] <= oRound[767:704];   S[14] <= oRound[703:640];
                S[15] <= oRound[639:576];   S[16] <= oRound[575:512];   S[17] <= oRound[511:448];
                S[18] <= oRound[447:384];   S[19] <= oRound[383:320];   S[20] <= oRound[319:256];
                S[21] <= oRound[255:192];   S[22] <= oRound[191:128];   S[23] <= oRound[127:64];
                S[24] <= oRound[63:0];
                
            end else if (shift_active) begin
                // SHIFT LEFT STATE DATA
                S[0]  <= S[1];  S[1]  <= S[2];  S[2]  <= S[3];  S[3]  <= S[4];  S[4]  <= S[5];
                S[5]  <= S[6];  S[6]  <= S[7];  S[7]  <= S[8];  S[8]  <= S[9];  S[9]  <= S[10];
                S[10] <= S[11]; S[11] <= S[12]; S[12] <= S[13]; S[13] <= S[14]; S[14] <= S[15];
                S[15] <= S[16]; S[16] <= S[17]; S[17] <= S[18]; S[18] <= S[19]; S[19] <= S[20];
                S[20] <= S[21]; S[21] <= S[22]; S[22] <= S[23]; S[23] <= S[24];
                
                if (FSMstate == ABSORB_SHIFT || FSMstate == PAD_ONLY_BLK)
                    S[24] <= S[0] ^ iword; // ABSORB_SHIFT
                else
                    S[24] <= S[0]; // SQUEEZE_SHIFT 
            end
        end
    end

    // SQUEEZE_OUTPUT_DATA
    assign oHash = {
        S[0][7:0],   S[0][15:8],  S[0][23:16], S[0][31:24], 
        S[0][39:32], S[0][47:40], S[0][55:48], S[0][63:56]
    };

endmodule