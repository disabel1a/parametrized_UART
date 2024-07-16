`ifndef _UART_INTERFACE_
`define _UART_INTERFACE_

interface uart_interface
  #(parameter
    DATA_WIDTH = 8);

    logic valid;                // Сигнал о собранных данных
    logic ready;                // Сигнал о готовности принимать или получать данные

    bit signal;                // TX - выход; RX - вход
    bit [DATA_WIDTH-1:0] data; // Данные

    /*-------------------------------------------------------------------------------
        Интерфейс для UART TX:
        -> data
        -> valid

        <- signal
        <- ready
    -------------------------------------------------------------------------------*/
    modport txif (
        input data, valid,
        output signal, ready
    );

    /*-------------------------------------------------------------------------------
        Интерфейс для UART RX:
        -> signal

        <- data
        <- valid
        <- ready
    -------------------------------------------------------------------------------*/
    modport rxif (
        input signal,
        output data, valid, ready 
    );

endinterface //uart_interface
`endif