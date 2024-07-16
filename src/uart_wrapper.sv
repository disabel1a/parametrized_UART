`timescale 1ns / 1ps
//`include "uart.sv"

module uart_wrapper
  #(parameter
    DATA_WIDTH = 8,
    CLK_FREQ = 100_000_000)
   (
    input  clk,
    input  set_l,
    input  rst_l,

    //  TX
    input[DATA_WIDTH:0]  data_tx,
    input  valid_tx,
    output ready_tx,
    output signal_tx,

    // RX
    input  signal_rx,
    output[DATA_WIDTH:0]  data_rx,
    output valid_rx,
    output ready_rx,
    output parity_err,

    // TUNER
    input[3:0] br,
    input[1:0] sbl,
    input parity_on,
    input seniority_h,
    input parity_set
    );

    uart_interface #(.DATA_WIDTH(DATA_WIDTH)) tx();
    uart_interface #(.DATA_WIDTH(DATA_WIDTH)) rx();
    uart_tuner_interface tuner(.br(br), .sbl(sbl), .parity_on(parity_on), .seniority_h(seniority_h), .parity_set(parity_set));

    uart #(DATA_WIDTH, CLK_FREQ) A_uart(.txif        (tx),
                                        .rxif        (rx),
                                        .tuner_if  (tuner),
                                        .clk       (clk),
                                        .rst_l     (rst_l),
                                        .set_l     (set_l),
                                        .parity_err(parity_err));

    assign tx.data = data_tx;
    assign tx.valid = valid_tx;
    assign ready_tx = tx.ready;
    assign signal_tx = tx.signal;

    assign data_rx = rx.data;
    assign valid_rx = rx.valid;
    assign ready_rx = rx.ready;
    assign rx.signal = signal_rx;

endmodule
