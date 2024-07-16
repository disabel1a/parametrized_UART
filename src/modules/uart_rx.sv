`ifndef _UART_RX_
`define _UART_RX_

`include "/home/user/E2/T1001/uart_rework/src/interfaces/uart_interface.sv"
`include "/home/user/E2/T1001/uart_rework/src/interfaces/uart_tuner_interface.sv"

module uart_rx
  #(parameter
    DATA_WIDTH = 8,
    CLK_FREQ = 100_000_000,
    
    localparam
    BIT_COUNTER_WIDTH = $clog2(DATA_WIDTH),
    CLK_COUNTER_SIZE  = $clog2((CLK_FREQ / 300) * 2))
   (
    /*-------------------------------------------------------------------------------
        Интерфейс для UART RX:
        -> signal

        <- data
        <- valid
        <- ready
    -------------------------------------------------------------------------------*/

    uart_interface.rxif rx,           // Интерфейс TX модуля
    input tuner_output_bus settings,  // Параметры отправки по UART
    input logic clk,                  // Тактовый сигнал
    input logic rst_l,                // Сигнал перезагрузки
    output logic parity_err);         // Сигнал об ошибке во время передачи данных

    enum bit [1:0] { IDLE, DATA, PARITY, STOP } state;  // Режимы работы (IDLE - ожидание сигнала на входе);
                                                        //               (DATA - получение данных);
                                                        //               (PARITY - детектирование ошибки по биту четности);
                                                        //               (STOP - Ввод времени ожидания стопового бита)

    bit [CLK_COUNTER_SIZE:0] clk_counter;     // Счетчик такта UART
    bit [BIT_COUNTER_WIDTH-1:0] bit_counter;  // Счетчик переданных битов (вычитание из общего количества передаваемых бит)
    bit [DATA_WIDTH-1:0] buffer;              // Буффер (хранимое значение data)
    bit parity_bit;                           // Счетчик четности 

    always_ff @( posedge clk, negedge rst_l) begin
        if(~rst_l) begin
            state <= IDLE;
            buffer        <= 0;  // Отчистака буффера
            clk_counter   <= 0;  // Сброс счетчиака тактов UART
            bit_counter   <= 0;  // Сброс счетчика битов 
            parity_bit    <= 0;  // Сброс счетчика четности
            parity_err    <= 0;  // Сброс маркера ошибки при подсчете четности
        end

        /*-------------------------------------------------------------------------------
            Переходы между режимами работы
        -------------------------------------------------------------------------------*/
        else begin
            case (state)
                /*-------------------------------------------------------------------------------
                    Режим IDLE:
                    Ожидает запрос получение данных по каналу (начинает прием при signal = 0),
                    Если есть запрос, происходит установка параметров приема,
                    после чего автомат переходит в состояние DATA.
                -------------------------------------------------------------------------------*/
                IDLE: begin
                    if (rx.signal == 0) begin
                        state <= DATA;
                        buffer      <= 0;
                        bit_counter <= (settings.seniority_h == 1) ? (DATA_WIDTH - 1) : 0;
                        clk_counter <= settings.pulse_width + (settings.pulse_width >> 1);
                        parity_bit  <= 0;
                        parity_err  <= 0;
                    end
                end

                /*-------------------------------------------------------------------------------
                    Режим DATA:
                    В соответствии с тактами UART принимает данные. Порядок приема данных
                    (от старшего / от младшего) определяется значением settings.seniority_h.

                    В качестве индекса бита выступает переменная bit_counter, которая
                    инкрементируется или декрементируется в зависимости от параметра
                    settings.seniority_h (значение канала записываается по индексу в буффер).

                    Параллельно с приемом вычисляется бит четности (parity_bit) - если 
                    встречается единица, то резутьтат складывается по модулю двойки (xor).

                    Когда все данные приняты, автомат переходит в состояние PARITY или STOP
                    (в зависимости от параметра settings.parity_on).
                -------------------------------------------------------------------------------*/
                DATA: begin
                    if (clk_counter > 0) begin
                        clk_counter <= clk_counter - 1;
                    end
                    else begin
                        buffer[bit_counter] <= rx.signal;
                        clk_counter <= settings.pulse_width;

                        if (settings.parity_on == 1) parity_bit <= parity_bit ^ rx.signal;

                        if (check_end_of_message()) begin
                            if (settings.parity_on == 1) state <= PARITY;
                            else state <= STOP;
                        end
                        else begin
                            bit_counter <= bit_counter + $signed(settings.seniority_h ? -1 : 1);
                        end
                    end
                end

                /*-------------------------------------------------------------------------------
                    Режим PARITY:
                    Сверяет бит четности в конце полученного сообщения (parity_bit),
                    после чего определяет есть ли ошибка при передаче (если есть ошибка
                    на выход parity_err выведется 1). Далее автомат переходит в режим STOP.
                -------------------------------------------------------------------------------*/
                PARITY: begin
                    if (clk_counter > 0) begin
                        clk_counter <= clk_counter - 1;
                    end
                    else begin
                        state <= STOP;
                        clk_counter <= settings.pulse_width;
                        parity_err <= ((parity_bit ^ settings.parity_set) == rx.signal) ? 0 : 1;
                    end
                end

                /*-------------------------------------------------------------------------------
                    Режим STOP:
                    Ожидает стопового бита, после чего переходит в режим IDLE.
                -------------------------------------------------------------------------------*/
                STOP: begin
                    if (clk_counter > 0) begin
                        clk_counter <= clk_counter - 1;
                    end
                    else if (rx.signal) begin
                        state <= IDLE;
                        parity_err <= 0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
    
    /*-------------------------------------------------------------------------------
        Управление выходными сигналми
    -------------------------------------------------------------------------------*/
    always_ff @( posedge clk, negedge rst_l ) begin
        if (~rst_l) begin
            rx.valid    <= 0;
            parity_err  <= 0;  // Обнуление индикатора ошибки во время передачи
        end
        else begin
            if((state == STOP) && (clk_counter == 0) && ~rx.valid) begin
                rx.valid <= 1;
            end
            else if (rx.valid && rx.ready) begin
                rx.valid <= 0;
            end
        end
    end

    assign rx.data = (rx.valid) ? buffer : 0;
    assign rx.ready = (state == IDLE);

    function bit check_end_of_message();  // Проверка конца сообщения с учетом порядка вывода битов
        if (((bit_counter == DATA_WIDTH - 1) & (~settings.seniority_h)) || ((bit_counter == 0) & (settings.seniority_h))) begin
            return 1; 
        end
        return 0;
    endfunction

endmodule
`endif