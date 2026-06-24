
module ML_DSA_SHAKE_PADDER (
    input  wire [63:0] iData,
    input  wire        iLast, 
    input  wire        iLast_16bit, 
    input  wire        iMode,
    input  wire [2:0]  iState,
    input  wire [4:0]  iCycle_Cnt, 
    input  wire [4:0]  iEof_Word_Idx,
    input  wire        iMsg_Ended, 
    input  wire        iInput_Fire,
    
    output wire [63:0] oWord
);
    localparam ABSORB_SHIFT = 3'd1;
    localparam PAD_ONLY_BLK = 3'd2;
    localparam [7:0]  SUFFIX_PAD_1F = 8'h1F;
    localparam [63:0] SUFFIX_PAD_80 = {8'h80, 56'h00};
    
    //1:SHAKE128 (21 LANES) OR 0:SHAKE256(17 LANES)
    wire [4:0] rate_lanes = (iMode == 1'b0) ? 5'd21 : 5'd17;
    
    wire [63:0] data_swapped = {
        iData[7:0], iData[15:8], iData[23:16], iData[31:24], 
        iData[39:32], iData[47:40], iData[55:48], iData[63:56]
    };
    
    wire [63:0] data_16bit_padded = {40'h00, SUFFIX_PAD_1F, iData[7:0], iData[15:8]};
    wire [63:0] just_SUFFIX_PAD_1F       = {56'h00, SUFFIX_PAD_1F};

    // =================================================================
    // 2. MUX TẦNG 1: CHỌN DỮ LIỆU CƠ SỞ (BASE WORD)
    // =================================================================
    wire [63:0] base_word;
    
    assign base_word = 
        // TH1: Mạch đang chạy bù Block rỗng -> Cấy 0x1F ở nhịp đầu tiên
        (iState == PAD_ONLY_BLK && iCycle_Cnt == 5'd0) ? just_SUFFIX_PAD_1F :
        
        // TH2: Mạch đã kết thúc data, đang ở nhịp cấy 0x1F sang Word tiếp theo
        (iState == ABSORB_SHIFT && iMsg_Ended && iCycle_Cnt == iEof_Word_Idx) ? just_SUFFIX_PAD_1F :
        
        // TH3: Đang hút data thật
        (iState == ABSORB_SHIFT && !iMsg_Ended && iInput_Fire) ? 
            ((iLast && iLast_16bit) ? data_16bit_padded : data_swapped) :
            
        // Mặc định: Trả về 0 (Sẽ thực hiện XOR với 0 ở Datapath, tốn ít điện năng)
        64'h0;

    // =================================================================
    // 3. MUX TẦNG 2 & CỔNG OR: CẤY BIT CHỐT KẾT THÚC (0x80)
    // =================================================================
    wire is_last_lane = (iCycle_Cnt == (rate_lanes - 5'd1));
    
    // Bật cờ cần chốt 0x80 nếu đang ở nhịp cuối cùng của Rate (Word 16 hoặc Word 20)
    wire need_80_absorb = (iState == ABSORB_SHIFT) && is_last_lane && (iMsg_Ended || (iInput_Fire && iLast));
    wire need_80_padblk = (iState == PAD_ONLY_BLK) && is_last_lane;

    // Ngoại lệ: Nếu data vừa khít tròn lẳn Rate (Tròn 136 byte), cấm chốt 0x80 ở đây.
    // Phải nhường lại việc chốt 0x80 cho block PAD_ONLY_BLK tiếp theo.
    wire skip_80 = (iState == ABSORB_SHIFT) && (!iMsg_Ended && iInput_Fire && iLast && !iLast_16bit);

    // Cổng Logic cuối cùng xuất ra Datapath
    assign oWord = ((need_80_absorb && !skip_80) || need_80_padblk) ? (base_word | SUFFIX_PAD_80) : base_word;

endmodule