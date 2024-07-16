`ifndef _UART_TUNER_
`define _UART_TUNER_

`include "/home/user/E2/T1001/uart_rework/src/interfaces/uart_tuner_interface.sv"

module uart_tuner
  #(parameter
    CLK_FREQ = 100_000_000)
   (
    uart_tuner_interface tuner_if,

    input logic condition,  // Условие настройки новых параметров (для uart - при ready = 1 обоих модулей RX и TX)

    input logic rst_l,
    input logic set_l,

    output tuner_output_bus settings);  // Сохраненные настройки UART модуля
    
//    tuner_output_bus settings;

//    assign settings = settings;

    always_latch begin
        if (~rst_l) begin
            settings.sbl         <= ONE_AND_HALF;
            settings.parity_on   <= 1;
            settings.parity_set  <= 1;
            settings.seniority_h <= 1;
        end

        else if (condition && ~set_l) begin
			count_pulse_width();
            settings.sbl         <= tuner_if.sbl;
            settings.parity_on   <= tuner_if.parity_on;
            settings.parity_set  <= tuner_if.parity_set;
            settings.seniority_h <= tuner_if.seniority_h;
        end
        else begin
        	settings <= settings;
        end
    end

    task count_pulse_width(); // Выбор ширины импульса в зависимости от скорости UART (9600 по умолчанию)
    begin
        case (tuner_if.br)
            R_300:    settings.pulse_width <= CLK_FREQ / 300;
            R_600:    settings.pulse_width <= CLK_FREQ / 600;
            R_1200:   settings.pulse_width <= CLK_FREQ / 1200;
            R_2400:   settings.pulse_width <= CLK_FREQ / 2400;
            R_4800:   settings.pulse_width <= CLK_FREQ / 4800;
            R_9600:   settings.pulse_width <= CLK_FREQ / 9600;
            R_19200:  settings.pulse_width <= CLK_FREQ / 19200;
            R_38400:  settings.pulse_width <= CLK_FREQ / 38400;
            R_57600:  settings.pulse_width <= CLK_FREQ / 57600;
            R_115200: settings.pulse_width <= CLK_FREQ / 115200;
            R_230400: settings.pulse_width <= CLK_FREQ / 230400;
            R_460800: settings.pulse_width <= CLK_FREQ / 460800;
            R_921600: settings.pulse_width <= CLK_FREQ / 921600;
            default:  settings.pulse_width <= CLK_FREQ / 9600;
        endcase
    end
    endtask

endmodule

`endif