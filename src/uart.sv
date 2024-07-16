`include "/home/user/E2/T1001/uart_rework/src/interfaces/uart_interface.sv"
`include "/home/user/E2/T1001/uart_rework/src/interfaces/uart_tuner_interface.sv"

`include "/home/user/E2/T1001/uart_rework/src/modules/uart_rx.sv"
`include "/home/user/E2/T1001/uart_rework/src/modules/uart_tx.sv"
`include "/home/user/E2/T1001/uart_rework/src/modules/uart_tuner.sv"

module uart 
  #(parameter
    DATA_WIDTH = 8,
    CLK_FREQ = 100_000_000)
   (
    /*-------------------------------------------------------------------------------
        Интерфейс для UART TX:    Интерфейс для UART RX:
        -> data                   -> signal
        -> valid
                                  <- data  
        <- signal                 <- valid
        <- ready                  <- ready
    -------------------------------------------------------------------------------*/

    uart_interface txif,             // Интерфейс TX 
    uart_interface rxif,             // Интерфейс RX

    /*-------------------------------------------------------------------------------
        Интерфейс настройщика:
        -> br
        -> sbl
        -> parity_on
        -> seniority_h
        -> parity_set
    -------------------------------------------------------------------------------*/

    uart_tuner_interface tuner_if,  // Интерфейс настройщика

    input logic clk,                // Вход тактовго сигнала
    input logic rst_l,              // Вход сигнала перезагрузки
    input logic set_l,              // Вход сигнала настройки

    output logic parity_err);       // Сигнал об ошибке во время передачи данных

    logic condition;
    tuner_output_bus settings;

    uart_tuner #(.CLK_FREQ(CLK_FREQ))
    tuner(.tuner_if(tuner_if), .rst_l(rst_l), .set_l(set_l), .condition(condition), .settings(settings));

    uart_tx #(.DATA_WIDTH(DATA_WIDTH), .CLK_FREQ(CLK_FREQ))
    tx_module(.tx(txif), .clk(clk), .rst_l(rst_l), .settings(settings));

    uart_rx #(.DATA_WIDTH(DATA_WIDTH), .CLK_FREQ(CLK_FREQ))
    rx_module(.rx(rxif), .clk(clk), .rst_l(rst_l), .settings(settings), .parity_err(parity_err));

    assign condition = txif.ready && rxif.ready;
    
endmodule