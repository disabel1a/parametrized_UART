`include "../src/uart.sv"

`timescale 1ns/100ps

module uart_to_uart;
    localparam DATA_WIDTH = 8;
    localparam CLK_FREQ = 10_000_000;
    localparam MULT = 5;
    localparam CLK_FREQ_DIF = CLK_FREQ * MULT;
    localparam HALF_CLK_WIDTH = 5;
    localparam CLK_SHIFT = HALF_CLK_WIDTH / 2;

    bit[DATA_WIDTH-1:0] data_in;
    bit[DATA_WIDTH-1:0] data_out;

    /*-------------------------------------------------------------------------------
        Интерфейс для UART TX:    Интерфейс для UART RX:
        -> data                   -> signal
        -> valid
                                  <- data  
        <- signal                 <- valid
        <- ready                  <- ready
    -------------------------------------------------------------------------------*/

    /*-------------------------------------------------------------------------------
        Интерфейс настройщика:
        -> br
        -> sbl
        -> parity_on
        -> seniority_h
        -> parity_set
    -------------------------------------------------------------------------------*/

    typedef longint unsigned size_t;

    //-----------------------------------------------
    //  UART модуль A c частотой CLK_FREQ
    //-----------------------------------------------

    uart_interface #(.DATA_WIDTH(DATA_WIDTH)) A_tx();
    uart_interface #(.DATA_WIDTH(DATA_WIDTH)) A_rx();
    uart_tuner_interface A_tuner();
    logic A_parity_err;

    logic A_clk;
    logic A_rst_l;
    logic A_set_l;

    uart #(DATA_WIDTH, CLK_FREQ) A_uart(.txif        (A_tx),
                                        .rxif        (A_rx),
                                        .tuner_if  (A_tuner),
                                        .clk       (A_clk),
                                        .rst_l     (A_rst_l),
                                        .set_l     (A_set_l),
                                        .parity_err(A_parity_err));

    //-----------------------------------------------
    //  UART модуль B с частотой CLK_FREQ_DIF
    //-----------------------------------------------

    uart_interface #(.DATA_WIDTH(DATA_WIDTH)) B_tx();
    uart_interface #(.DATA_WIDTH(DATA_WIDTH)) B_rx();
    uart_tuner_interface B_tuner();
    logic B_parity_err;

    logic B_clk;
    logic B_rst_l;
    logic B_set_l;

    uart #(DATA_WIDTH, CLK_FREQ_DIF) B_uart(.txif        (B_tx),
                                            .rxif        (B_rx),
                                            .tuner_if  (B_tuner),
                                            .clk       (B_clk),
                                            .rst_l     (B_rst_l),
                                            .set_l     (B_set_l),
                                            .parity_err(B_parity_err));

    //---------------------------------------

    assign B_rx.signal = A_tx.signal;
    assign A_rx.signal = B_tx.signal;

    assign A_tx.data = data_in;
    assign data_out  = B_rx.data;

    size_t pulse_width;

    /* --------------------------------------
        Тестирование
    -------------------------------------- */

    initial begin
        A_clk = 1;
        B_clk = 1;

        A_rst_l = 0;
        B_rst_l = 0;

        A_set_l = 1;
        B_set_l = 1;

        repeat (5) #5;

        A_rst_l = 1;
        B_rst_l = 1;

        repeat (5) invert_clks();

        // /* ------------------------------------------------------
        //     Скорость UART:              R_9600
        //     Длинна стопового бита:      TWO
        //     Порядок вывода битов:       От старшего
        //     Способ учета бита четности: С учетом бита четности
        // ------------------------------------------------------*/

        // set_uarts(R_9600, TWO, 1, 1, 1);

        // repeat(2) invert_clks();

        // data_in = 'b0000_1111;
        // A_tx.valid = 1;

        // pulse_width = count_pulse_width(R_9600);

        // repeat(2) invert_clks();
        // A_tx.valid = 0;
        // repeat ((pulse_width * 2) * (DATA_WIDTH + 6)) invert_clks();

        // /* ------------------------------------------------------
        //     Скорость UART:              R_9600
        //     Длинна стопового бита:      ONE
        //     Порядок вывода битов:       От старшего
        //     Способ учета бита четности: *(Без бита четности)
        // ------------------------------------------------------*/

        // set_uarts(R_9600, ONE, 0, 0, 1);

        // repeat(2) invert_clks();

        // data_in = 'b0100_0111;
        // A_tx.valid = 1;

        // pulse_width = count_pulse_width(R_9600);

        // repeat(2) invert_clks();
        // A_tx.valid = 0;
        // repeat ((pulse_width * 2) * (DATA_WIDTH + 6)) invert_clks();

        // /* ------------------------------------------------------
        //     Скорость UART:              R_4800
        //     Длинна стопового бита:      ONE_AND_HALF
        //     Порядок вывода битов:       От младшего
        //     Способ учета бита четности: Без учета бита четности
        // ------------------------------------------------------*/

        // set_uarts(R_4800, ONE_AND_HALF, 1, 0, 0);

        // repeat(2) invert_clks();

        // data_in = 'b0100_0110;
        // A_tx.valid = 1;

        // pulse_width = count_pulse_width(R_4800);

        // repeat(2) invert_clks();
        // A_tx.valid = 0;
        // repeat ((pulse_width * 2) * (DATA_WIDTH + 6)) invert_clks();

        check_freqs();

        $finish;
    end

    task check_freqs();
        baud_rate br;
        for(br = R_300; br != br.last(); br = br.next()) begin
            set_uarts(br, ONE, 1, 1, 1);

            repeat(2) invert_clks();

            data_in = 'b0010_0110;
            A_tx.valid = 1;

            pulse_width = count_pulse_width(br);

            repeat(2) invert_clks();
            A_tx.valid = 0;
            repeat ((pulse_width * 2) * (DATA_WIDTH + 1)) begin
                if (data_out != 0) begin
                    $display($time, ") (br%s) data_in: %b; data_out: %b; valid: %b\n", br, data_in, data_out, B_rx.valid);
                end 
                invert_clks();
            end
        end

        set_uarts(br.last(), ONE, 1, 1, 1);

        repeat(2) invert_clks();

        data_in = 'b0010_0110;
        A_tx.valid = 1;

        pulse_width = count_pulse_width(br.last());

        repeat(2) invert_clks();
        A_tx.valid = 0;
        repeat ((pulse_width * 2) * (DATA_WIDTH + 1)) begin
            if (data_out != 0 && B_rx.valid) begin
                $display($time, ") (br%s) data_in: %b; data_out: %b; valid: %b\n", br, data_in, data_out, B_rx.valid);
            end 
            invert_clks();
            if (data_out != 0 && B_rx.valid) begin
                $display($time, ") (br%s) data_in: %b; data_out: %b; valid: %b\n", br, data_in, data_out, B_rx.valid);
            end 
        end
    endtask

    task invert_clks();
        A_clk = ~A_clk;
        repeat (MULT) begin
            #3;
            B_clk = ~B_clk;
            #3;
        end;
    endtask

    task set_uarts(baud_rate br, stop_bit_length sbl, bit parity_on, bit parity_set, bit seniority_h);

        A_tuner.br = br;
        B_tuner.br = br;

        A_tuner.sbl = sbl;
        B_tuner.sbl = sbl;

        A_tuner.parity_set = parity_set;
        B_tuner.parity_set = parity_set;

        A_tuner.parity_on = parity_on;
        B_tuner.parity_on = parity_on;

        A_tuner.seniority_h = seniority_h;
        B_tuner.seniority_h = seniority_h;

        repeat(4) invert_clks();

        A_set_l = 0;
        B_set_l = 0;

        repeat(4) invert_clks();

        A_set_l = 1;
        B_set_l = 1;

        repeat(4) invert_clks();
    endtask

    function size_t count_pulse_width(baud_rate _br);
        case (_br)
            R_300:    return CLK_FREQ_DIF / 300;
            R_600:    return CLK_FREQ_DIF / 600;
            R_1200:   return CLK_FREQ_DIF / 1200;
            R_2400:   return CLK_FREQ_DIF / 2400;
            R_4800:   return CLK_FREQ_DIF / 4800;
            R_9600:   return CLK_FREQ_DIF / 9600;
            R_19200:  return CLK_FREQ_DIF / 19200;
            R_38400:  return CLK_FREQ_DIF / 38400;
            R_57600:  return CLK_FREQ_DIF / 57600;
            R_115200: return CLK_FREQ_DIF / 115200;
            R_230400: return CLK_FREQ_DIF / 230400;
            R_460800: return CLK_FREQ_DIF / 460800;
            R_921600: return CLK_FREQ_DIF / 921600;
            default:  return CLK_FREQ_DIF / 9600;
        endcase
    endfunction
    
endmodule