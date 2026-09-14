`timescale 1ns/1ps

module ntt_top_dual (
    input  wire clk,
    input  wire rst_n,
    input  wire start,
    input  wire mode,
    input  wire [11:0] data_in_0,
    input  wire [11:0] data_in_1,
    output wire [11:0] data_out_0,
    output wire [11:0] data_out_1,
    output wire busy,
    output wire done
);

    wire [2:0]  stage;
    wire [5:0]  step;
    wire        calc_en;
    wire [11:0] twiddle_factor0, twiddle_factor1;
    wire        load_en;
    wire [6:0]  load_addr;

    wire [11:0] dbf_in_a0, dbf_in_b0, dbf_in_a1, dbf_in_b1;
    wire [11:0] dbf_out_y00, dbf_out_y01, dbf_out_y10, dbf_out_y11;

    ntt_fsm_rom_dual u_fsm (
        .clk             (clk),
        .rst_n           (rst_n),
        .start           (start),
        .stage           (stage),
        .step            (step),
        .calc_en         (calc_en),
        .twiddle_factor0 (twiddle_factor0),
        .twiddle_factor1 (twiddle_factor1),
        .load_en         (load_en),
        .load_addr       (load_addr),
        .busy            (busy),
        .done            (done)
    );

    // Sử dụng module dual_butterfly của bạn
    dual_butterfly u_bfu_dual (
        .clk         (clk),
        .rst_n       (rst_n),
        .mode        (mode),
        .in_a0       (dbf_in_a0),
        .in_b0       (dbf_in_b0),
        .in_a1       (dbf_in_a1),
        .in_b1       (dbf_in_b1),
        .in_twiddle0 (twiddle_factor0),
        .in_twiddle1 (twiddle_factor1),
        .out_y00     (dbf_out_y00),
        .out_y01     (dbf_out_y01),
        .out_y10     (dbf_out_y10),
        .out_y11     (dbf_out_y11)
    );

    nmi_reorder_dual u_nmi (
        .clk         (clk),
        .rst_n       (rst_n),
        .load_en     (load_en),
        .load_addr   (load_addr),
        .load_data0  (data_in_0),
        .load_data1  (data_in_1),
        .stage       (stage),
        .step        (step),
        .calc_en     (calc_en),
        .dbf_out_y00 (dbf_out_y00),
        .dbf_out_y01 (dbf_out_y01),
        .dbf_out_y10 (dbf_out_y10),
        .dbf_out_y11 (dbf_out_y11),
        .dbf_in_a0   (dbf_in_a0),
        .dbf_in_b0   (dbf_in_b0),
        .dbf_in_a1   (dbf_in_a1),
        .dbf_in_b1   (dbf_in_b1)
    );

    assign data_out_0 = dbf_out_y00;
    assign data_out_1 = dbf_out_y10;

endmodule