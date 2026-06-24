module ML_DSA_LIGHTWEIGHT_SHAKE (
    input  wire        iClk,
    input  wire        iRst_n,
    input  wire        iStart,
    input  wire        iMode,
    
    // Input
    input  wire [63:0] iData,
    input  wire        iValid,
    input  wire        iLast,
    input  wire        iLast_16bit,
    output wire        oReady,
    
    // Output (XOF Squeeze)
    input  wire        iSqueeze_En,
    output wire [63:0] oHash,
    output wire        oHash_Valid,
    output wire        oDone
);

    // Internal Wires
    wire [2:0]  FSMstate;
    wire [4:0]  cycle_cnt_w;
    wire [4:0]  iRC;
    wire        shift_active;
    wire        iReady;
    wire        MessageEnded;
    wire [4:0]  eof_word_idx_w;

    wire [63:0]   iword;
    wire [1599:0] oState;
    wire [1599:0] oRound;
    wire [63:0]   RC;

    ML_DSA_SHAKE_FSM u_fsm (
        .clk(iClk), .rst_n(iRst_n), .start(iStart), .mode(iMode),
        .ivalid(iValid), .ilast(iLast), .ilast_16bit(iLast_16bit), .isqueeze_en(iSqueeze_En),
        .oready(oReady), .ohash_valid(oHash_Valid), .odone(oDone),
        .o_state(FSMstate), .o_cycle_cnt(cycle_cnt_w), .o_round_cnt(iRC),
        .o_shift_active(shift_active), .o_input_fire(iReady),
        .o_msg_ended(MessageEnded), .o_eof_word_idx(eof_word_idx_w)
    );

    ML_DSA_SHAKE_PADDER u_padder (
        .iData(iData), .iLast(iLast), .iLast_16bit(iLast_16bit), .iMode(iMode),
        .iState(FSMstate), .iCycle_Cnt(cycle_cnt_w), 
        .Word_Idx(eof_word_idx_w),     
        .MessageEnded(MessageEnded), .iReady(iReady),
        .oWord(iword)                  
    );

    ML_DSA_SHAKE_DATAPATH u_datapath (
        .iclk(iClk), .rst_n(iRst_n), .FlatStart(iStart),
        .FSMstate(FSMstate), .shift_active(shift_active),
        .iword(iword), .oRound(oRound),
        .oState(oState), .oHash(oHash)
    );

    SHAKE_KECCAK_F u_math (
        .iState(oState), 
        .iRound_Index(iRC), 
        .oState(oRound)
    );

endmodule
