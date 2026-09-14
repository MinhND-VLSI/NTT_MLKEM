`timescale 1ns/1ps

module nmi_reorder_dual (
    input  wire clk,
    input  wire rst_n,

    // Nạp đồng thời 2 hệ số từ ngoài
    input  wire        load_en,
    input  wire [6:0]  load_addr,     // 0 đến 127
    input  wire [11:0] load_data0,
    input  wire [11:0] load_data1,

    input  wire [2:0]  stage,         // 1 đến 7
    input  wire [5:0]  step,          // 0 đến 63
    input  wire        calc_en,

    // Nhận kết quả từ 2 bướm (4 kết quả)
    input  wire [11:0] dbf_out_y00,
    input  wire [11:0] dbf_out_y01,
    input  wire [11:0] dbf_out_y10,
    input  wire [11:0] dbf_out_y11,

    // Xuất toán hạng cho 2 bướm (4 toán hạng)
    output wire [11:0] dbf_in_a0,
    output wire [11:0] dbf_in_b0,
    output wire [11:0] dbf_in_a1,
    output wire [11:0] dbf_in_b1
);

    reg [11:0] mem [0:255];

    function [7:0] get_addr_a(input [2:0] stage, input [6:0] stp);
        case (stage)
            3'd1: get_addr_a = {1'b0, stp[6:0]};
            3'd2: get_addr_a = {stp[6], 1'b0, stp[5:0]};
            3'd3: get_addr_a = {stp[6:5], 1'b0, stp[4:0]};
            3'd4: get_addr_a = {stp[6:4], 1'b0, stp[3:0]};
            3'd5: get_addr_a = {stp[6:3], 1'b0, stp[2:0]};
            3'd6: get_addr_a = {stp[6:2], 1'b0, stp[1:0]};
            3'd7: get_addr_a = {stp[6:1], 1'b0, stp[0]};
            default: get_addr_a = {1'b0, stp[6:0]};
        endcase
    endfunction

    function [7:0] get_addr_b(input [2:0] stg, input [6:0] stp);
        case (stg)
            3'd1: get_addr_b = {1'b1, stp[6:0]};
            3'd2: get_addr_b = {stp[6], 1'b1, stp[5:0]};
            3'd3: get_addr_b = {stp[6:5], 1'b1, stp[4:0]};
            3'd4: get_addr_b = {stp[6:4], 1'b1, stp[3:0]};
            3'd5: get_addr_b = {stp[6:3], 1'b1, stp[2:0]};
            3'd6: get_addr_b = {stp[6:2], 1'b1, stp[1:0]};
            3'd7: get_addr_b = {stp[6:1], 1'b1, stp[0]};
            default: get_addr_b = {1'b1, stp[6:0]};
        endcase
    endfunction

    // 2 bướm tính toán 2 bước liên tiếp song song
    wire [6:0] stp0 = {step, 1'b0};
    wire [6:0] stp1 = {step, 1'b1};

    wire [7:0] rd_addr_a0 = get_addr_a(stage, stp0);
    wire [7:0] rd_addr_b0 = get_addr_b(stage, stp0);
    wire [7:0] rd_addr_a1 = get_addr_a(stage, stp1);
    wire [7:0] rd_addr_b1 = get_addr_b(stage, stp1);

    assign dbf_in_a0 = mem[rd_addr_a0];
    assign dbf_in_b0 = mem[rd_addr_b0];
    assign dbf_in_a1 = mem[rd_addr_a1];
    assign dbf_in_b1 = mem[rd_addr_b1];

    // Trì hoãn 2 chu kỳ để đồng bộ với pipeline của cánh bướm
    reg [7:0] delay_a0 [0:1], delay_b0 [0:1];
    reg [7:0] delay_a1 [0:1], delay_b1 [0:1];
    reg delay_en [0:1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            delay_a0[0] <= 8'd0; delay_a0[1] <= 8'd0;
            delay_b0[0] <= 8'd0; delay_b0[1] <= 8'd0;
            delay_a1[0] <= 8'd0; delay_a1[1] <= 8'd0;
            delay_b1[0] <= 8'd0; delay_b1[1] <= 8'd0;
            delay_en[0] <= 1'b0; delay_en[1] <= 1'b0;
        end else begin
            delay_a0[0] <= rd_addr_a0;
            delay_b0[0] <= rd_addr_b0;
            delay_a1[0] <= rd_addr_a1;
            delay_b1[0] <= rd_addr_b1;
            delay_en[0] <= calc_en;

            delay_a0[1] <= delay_a0[0];
            delay_b0[1] <= delay_b0[0];
            delay_a1[1] <= delay_a1[0];
            delay_b1[1] <= delay_b1[0];
            delay_en[1] <= delay_en[0];
        end
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 256; i = i + 1) mem[i] <= 12'd0;
        end else begin
            if (load_en) begin
                // Nạp 2 hệ số mỗi chu kỳ
                mem[{load_addr, 1'b0}] <= load_data0;
                mem[{load_addr, 1'b1}] <= load_data1;
            end else if (delay_en[1]) begin
                // Ghi đè 4 kết quả từ 2 bướm
                mem[delay_a0[1]] <= dbf_out_y00;
                mem[delay_b0[1]] <= dbf_out_y01;
                mem[delay_a1[1]] <= dbf_out_y10;
                mem[delay_b1[1]] <= dbf_out_y11;
            end
        end
    end

endmodule