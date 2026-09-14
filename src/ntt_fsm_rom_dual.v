`timescale 1ns/1ps

module ntt_fsm_rom_dual (
    input  wire clk,
    input  wire rst_n,
    input  wire start,

    output reg  [2:0]  stage,          // 1 đến 7
    output reg  [5:0]  step,           // 0 đến 63 (64 bước)
    output reg         calc_en,        // 1 ở step 0..63
    output reg  [11:0] twiddle_factor0,
    output reg  [11:0] twiddle_factor1,

    output reg         load_en,
    output reg  [6:0]  load_addr,      // 0 đến 127 (nạp 2 hệ số/chu kỳ)
    output reg         busy,
    output reg         done
);

    localparam STATE_IDLE = 2'b00;
    localparam STATE_LOAD = 2'b01; // Nạp 128 nhịp (mỗi nhịp 2 hệ số = 256 điểm)
    localparam STATE_RUN  = 2'b10; // Chạy 7 tầng (mỗi tầng 64 bước + 3 nhịp xả pipeline = 67 nhịp)
    localparam STATE_DONE = 2'b11;

    reg [1:0] state, next_state;
    reg [7:0] load_cnt; // Đếm 0 đến 127
    reg [6:0] step_cnt; // Đếm 0 đến 66 (64 bước tính + 3 nhịp xả ống)

    reg [11:0] rom_twiddle [0:127];
    initial begin
        $readmemh("twiddle_factors.hex", rom_twiddle);
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= STATE_IDLE;
            load_cnt <= 8'd0;
            stage    <= 3'd1;
            step_cnt <= 7'd0;
        end else begin
            state <= next_state;
            if (state == STATE_LOAD) begin
                load_cnt <= load_cnt + 1'b1;
            end else begin
                load_cnt <= 8'd0;
            end

            if (state == STATE_RUN) begin
                if (step_cnt == 7'd66) begin
                    step_cnt <= 7'd0;
                    if (stage == 3'd7) begin
                        stage <= 3'd1;
                    end else begin
                        stage <= stage + 1'b1;
                    end
                end else begin
                    step_cnt <= step_cnt + 1'b1;
                end
            end else if (state != STATE_LOAD) begin
                stage    <= 3'd1;
                step_cnt <= 7'd0;
            end
        end
    end

    always @(*) begin
        case (state)
            STATE_IDLE: next_state = start ? STATE_LOAD : STATE_IDLE;
            STATE_LOAD: next_state = (load_cnt == 8'd127) ? STATE_RUN : STATE_LOAD;
            STATE_RUN:  next_state = (stage == 3'd7 && step_cnt == 7'd66) ? STATE_DONE : STATE_RUN;
            STATE_DONE: next_state = STATE_IDLE;
            default:    next_state = STATE_IDLE;
        endcase
    end

    // Tính bước logic cho bướm 0 và bướm 1
    wire [6:0] step_bf0 = {step_cnt[5:0], 1'b0};
    wire [6:0] step_bf1 = {step_cnt[5:0], 1'b1};

    wire [6:0] rom_addr0 = (7'd1 << (stage - 1)) + (step_bf0 >> (4'd8 - stage));
    wire [6:0] rom_addr1 = (7'd1 << (stage - 1)) + (step_bf1 >> (4'd8 - stage));

    always @(*) begin
        step      = step_cnt[5:0];
        calc_en   = (state == STATE_RUN && step_cnt < 7'd64);
        load_en   = (state == STATE_LOAD);
        load_addr = load_cnt[6:0];
        busy      = (state == STATE_LOAD || state == STATE_RUN);
        done      = (state == STATE_DONE);

        twiddle_factor0 = (state == STATE_RUN) ? rom_twiddle[rom_addr0] : 12'd2285;
        twiddle_factor1 = (state == STATE_RUN) ? rom_twiddle[rom_addr1] : 12'd2285;
    end

endmodule