`ifndef _UART_TUNER_INTERFACE_
`define _UART_TUNER_INTERFACE_

typedef enum bit [3:0] { 
                             R_300    = 'b0000, R_600    = 'b0001,
                             R_1200   = 'b0010, R_2400   = 'b0011,
                             R_4800   = 'b0100, R_9600   = 'b0101,
                             R_19200  = 'b0110, R_38400  = 'b0111,
                             R_57600  = 'b1000, R_115200 = 'b1001,
                             R_230400 = 'b1010, R_460800 = 'b1011,
                             R_921600 = 'b1100
                           } baud_rate; // Скорость UART

typedef enum bit [1:0] { ONE_AND_HALF = 'b00, ONE = 'b01, TWO = 'b10 } stop_bit_length; // Длина стопового бита

typedef struct packed {
    bit [18:0] pulse_width;  // Установленная ширина пульса (19 бит - при максимально возможном значении)
    stop_bit_length sbl;     // Установленное значение длины стопового бита

    bit parity_on;           // Установленное занчение использования бита четности
    bit seniority_h;         // Установленное значение порядка отправки битов

    bit parity_set;          // Установелнное значение бита четности
  
} tuner_output_bus;  // Данные, сохраненные в памяти установщика

interface uart_tuner_interface
   (
    input baud_rate br,              // Скорость UART
    input stop_bit_length sbl,       // Длина стопового бита

    input bit parity_on,             // Использование бита парности
    input bit seniority_h,           // Порядок отправки битов: 1 - от старшего; 0 - от младшего

    input bit parity_set);           // Формат бита четности: 0 - (ODD) без добавления единицы; 1 - (EVEN) с добавлением единицы

endinterface

`endif