
module ML_DSA_SHAKE_FSM (
    input  wire       clk, rst_n, start, mode,
    input  wire       ivalid, ilast, ilast_16bit, isqueeze_en,
    output wire       oready, ohash_valid, odone,
    
    output wire [2:0] o_state,
    output wire [4:0] o_cycle_cnt, o_round_cnt,
    output wire       o_shift_active, o_input_fire, o_msg_ended,
    output wire [4:0] o_eof_word_idx
);
    localparam IDLE=3'd0, ABSORB_SHIFT=3'd1, PAD_ONLY_BLK=3'd2, PROCESS=3'd3, SQUEEZE_SHIFT=3'd4;
    
    reg [2:0] state, next_state;
    reg [4:0] cycle_cnt, round_cnt, eof_word_idx;
    reg msg_ended_latch, extra_pad_req;
    
    wire [4:0] rate_lanes = (mode == 1'b0) ? 5'd21 : 5'd17;

    assign oready = (state == ABSORB_SHIFT) && (cycle_cnt < rate_lanes) && !msg_ended_latch;
    wire input_fire = ivalid && oready;
    
    wire shift_active = (state == ABSORB_SHIFT && (input_fire || msg_ended_latch || cycle_cnt >= rate_lanes)) || 
                        (state == PAD_ONLY_BLK) || 
                        (state == SQUEEZE_SHIFT && (isqueeze_en || cycle_cnt >= rate_lanes));

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; cycle_cnt <= 0; round_cnt <= 0;
            msg_ended_latch <= 0; eof_word_idx <= 0; extra_pad_req <= 0;
        end else if (start) begin
            state <= ABSORB_SHIFT; cycle_cnt <= 0; round_cnt <= 0;
            msg_ended_latch <= 0; eof_word_idx <= 0; extra_pad_req <= 0;
        end else begin
            state <= next_state;

            if (next_state == PROCESS && state != PROCESS) round_cnt <= 0;
            else if (state == PROCESS && round_cnt < 23) round_cnt <= round_cnt + 1'b1;

            if (state == PROCESS && next_state != PROCESS) cycle_cnt <= 0; 
            else if (shift_active) cycle_cnt <= (cycle_cnt == 24) ? 5'd0 : cycle_cnt + 1'b1;

            if (state == ABSORB_SHIFT && input_fire && ilast && !msg_ended_latch) begin
                msg_ended_latch <= 1'b1;
                eof_word_idx <= cycle_cnt + (!ilast_16bit ? 1 : 0);
                if (cycle_cnt == (rate_lanes - 5'd1) && !ilast_16bit) extra_pad_req <= 1'b1;
            end
            if (state == PAD_ONLY_BLK && cycle_cnt == 24) extra_pad_req <= 0;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE:          next_state = IDLE; 
            ABSORB_SHIFT:  if (shift_active && cycle_cnt == 24) next_state = PROCESS;
            PAD_ONLY_BLK:  if (cycle_cnt == 24) next_state = PROCESS;
            PROCESS:       if (round_cnt == 23) next_state = (!msg_ended_latch) ? ABSORB_SHIFT : (extra_pad_req ? PAD_ONLY_BLK : SQUEEZE_SHIFT);
            SQUEEZE_SHIFT: if (shift_active && cycle_cnt == 24) next_state = PROCESS;
            default:       next_state = IDLE;
        endcase
    end

    assign ohash_valid = (state == SQUEEZE_SHIFT) && (cycle_cnt < rate_lanes) && isqueeze_en;
    assign odone       = (state == SQUEEZE_SHIFT);
    
    assign o_state = state; assign o_cycle_cnt = cycle_cnt; assign o_round_cnt = round_cnt;
    assign o_shift_active = shift_active; assign o_input_fire = input_fire; 
    assign o_msg_ended = msg_ended_latch; assign o_eof_word_idx = eof_word_idx;

endmodule