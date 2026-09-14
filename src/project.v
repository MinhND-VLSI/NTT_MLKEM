/*
 * Integrated Wrapper for ntt_top_dual on Tiny Tapeout
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_ntt_top (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // Vô hiệu hóa bus uio hai chiều
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    // Các tín hiệu giao tiếp nội bộ với ntt_top_dual
    reg         start_reg;
    reg         mode_reg;
    reg  [11:0] data_in_0_reg;
    reg  [11:0] data_in_1_reg;

    wire [11:0] data_out_0_wire;
    wire [11:0] data_out_1_wire;
    wire        busy_wire;
    wire        done_wire;

    // Quản lý nạp dữ liệu đầu vào (Ghép byte từ ui_in)
    // ui_in[7] = start
    // ui_in[6] = mode
    // ui_in[5:0] được ghép qua 2 chu kỳ để tạo dữ liệu 12-bit
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start_reg     <= 1'b0;
            mode_reg      <= 1'b0;
            data_in_0_reg <= 12'b0;
            data_in_1_reg <= 12'b0;
        end else begin
            start_reg <= ui_in[7];
            mode_reg  <= ui_in[6];
            
            // Ví dụ ghép byte: Byte 0 mang 6 bit thấp, Byte 1 mang 6 bit cao
            data_in_0_reg <= {uio_in[5:0], ui_in[5:0]};
            data_in_1_reg <= {uio_in[5:0], ui_in[5:0]}; // Hoặc dùng uio_in để cấp song song
        end
    end

    // Đẩy tín hiệu đầu ra ra bus uo_out
    // Bit 7: done, Bit 6: busy, Bit 5:0: data_out_0 (6 bit thấp)
    assign uo_out = {done_wire, busy_wire, data_out_0_wire[5:0]};

    // Instantiate khối NTT Core
    ntt_top_dual u_ntt_core (
        .clk        (clk),
        .rst_n      (rst_n),
        .start      (start_reg),
        .mode       (mode_reg),
        .data_in_0  (data_in_0_reg),
        .data_in_1  (data_in_1_reg),
        .data_out_0 (data_out_0_wire),
        .data_out_1 (data_out_1_wire),
        .busy       (busy_wire),
        .done       (done_wire)
    );

    // Xử lý các chân unused để tránh cảnh báo LVS/Synthesis
    wire _unused = &{ena, uio_in[7:6], data_out_0_wire[11:6], data_out_1_wire, 1'b0};

endmodule
