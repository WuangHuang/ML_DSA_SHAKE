
module ML_DSA_SHAKE_PADDER (
    input  wire [63:0] iData,
    input  wire        iLast, 
    input  wire        iLast_16bit, 
    input  wire        iMode,
    input  wire [2:0]  iState,
    input  wire [4:0]  iCycle_Cnt, 
    input  wire [4:0]  Word_Idx,
    input  wire        MessageEnded, 
    input  wire        iReady,
    
    output wire [63:0] oWord
);
    localparam ABSORB_SHIFT = 3'd1;
    localparam PAD_BLK = 3'd2; // Pad10*1
    localparam [7:0]  SUFFIX_PAD_1F = 8'h1F;
    localparam [63:0] SUFFIX_PAD_80 = {8'h80, 56'h00};
    
    //1:SHAKE128 (21 LANES) OR 0:SHAKE256(17 LANES)
    wire [4:0] rate_lanes = (iMode == 1'b0) ? 5'd21 : 5'd17;
    
    // iDATA_8BYTE - DATA_2BIT_PAD6BYTE  - ENDPADDING
    wire [63:0] data_swapped = {
        iData[7:0], iData[15:8], iData[23:16], iData[31:24], 
        iData[39:32], iData[47:40], iData[55:48], iData[63:56]
    };
    wire [63:0] DATA_2BIT_PAD6BYTE        = {40'h00, SUFFIX_PAD_1F, iData[7:0], iData[15:8]};
    wire [63:0] ENDPADDING                = {56'h00, SUFFIX_PAD_1F};

    // STAGE 1: SELECT BASE WORD  : iDATA_8BYTE - DATA_2BIT_PAD6BYTE  - ENDPADDING
    wire [63:0] base_word;
    
    assign base_word = 
        // PADD10*1 -> ENDPADDING -> DATAPATH
        (iState == PAD_BLK && iCycle_Cnt == 5'd0) ? ENDPADDING :
        
        // MESSAGE ENDED -> NEXT ENDPADDING -> DATAPATH
        (iState == ABSORB_SHIFT && MessageEnded && iCycle_Cnt == Word_Idx && iCycle_Cnt < rate_lanes) ? ENDPADDING :
        
        // DATA_INPUT -> DATAPATH
        (iState == ABSORB_SHIFT && !MessageEnded && iReady) ? 
            ((iLast && iLast_16bit) ? DATA_2BIT_PAD6BYTE : data_swapped) :
            
        // CAPACITOR 
        64'h0;

        

    //flag last block (block[16] or block[20])
    wire flag_last_lane = (iCycle_Cnt == (rate_lanes - 5'd1));
    // Expect Handle
    wire absorb_0x10 = (iState == ABSORB_SHIFT) && flag_last_lane && (MessageEnded || (iReady && iLast));
    wire padblk_0x10 = (iState == PAD_BLK) && flag_last_lane;
    wire skip_0x10 = (iState == ABSORB_SHIFT) && (!MessageEnded && iReady && iLast && !iLast_16bit);

    //  Datapath out
    assign oWord = ((absorb_0x10 && !skip_0x10) || padblk_0x10) ? (base_word | SUFFIX_PAD_80) : base_word;

endmodule