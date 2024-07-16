`ifndef _UART_TX_
`define _UART_TX_

`include "/home/user/E2/T1001/uart_rework/src/interfaces/uart_interface.sv"
`include "/home/user/E2/T1001/uart_rework/src/interfaces/uart_tuner_interface.sv"

module uart_tx 
  #(parameter
    DATA_WIDTH = 8,
    CLK_FREQ = 100_000_000,
    
    localparam
    BIT_COUNTER_WIDTH = $clog2(DATA_WIDTH),
    CLK_COUNTER_SIZE  = $clog2((CLK_FREQ / 300) * 2))
   (
    /*-------------------------------------------------------------------------------
        Интерфейс для UART TX:
        -> data
        -> valid

        <- signal
        <- ready
    -------------------------------------------------------------------------------*/

    uart_interface.txif tx,           // Интерфейс TX модуля
    input tuner_output_bus settings,  // Параметры отправки по UART
    input logic clk,                  // Тактовый сигнал
    input logic rst_l);               // Сигнал перезагрузки

    enum bit [1:0] { IDLE, DATA, PARITY, STOP } state;  // Режимы работы (IDLE - ожидание данных);
                                                        //               (DATA - передача данных);
                                                        //               (PARITY - добавление бита четности);
                                                        //               (STOP - добавление стопового бита)

    bit [CLK_COUNTER_SIZE:0] clk_counter;     // Счетчик такта UART
    bit [BIT_COUNTER_WIDTH-1:0] bit_counter;  // Счетчик переданных битов (вычитание из общего количества передаваемых бит)
    bit [DATA_WIDTH-1:0] buffer;              // Буффер (хранимое значение data)
    bit parity_bit;                           // Счетчик четности 

    always_ff @( posedge clk, negedge rst_l) begin
        if(~rst_l) begin
            state <= IDLE;
            tx.signal     <= 1;
            tx.ready      <= 1;
            buffer        <= 0;  // Отчистака буффера
            clk_counter   <= 0;  // Сброс счетчиака тактов UART
            bit_counter   <= 0;  // Сброс счетчика битов 
            parity_bit    <= 0;  // Сброс счетчика четности
        end

        /*-------------------------------------------------------------------------------
            Переходы между режимами работы
        -------------------------------------------------------------------------------*/
        else begin
            case (state)
                /*-------------------------------------------------------------------------------
                    Режим IDLE:
                    Ожидает запрос на отправку данных (tx.valid),
                    Если есть запрос, происходит установка параметров отправки с занесением
                    данных в буфер, после чего автомат переходит в состояние DATA.
                -------------------------------------------------------------------------------*/
                IDLE: begin
                    if (clk_counter > 0) begin
                        clk_counter <= clk_counter - 1;
                    end
                    else if (~tx.ready) begin
                        tx.ready  <= 1;
                        tx.signal <= 1;
                    end
                    else if (tx.valid) begin
                        state <= DATA;
                        tx.signal   <= 0;
                        tx.ready    <= 0;
                        buffer      <= tx.data;
                        bit_counter <= (settings.seniority_h == 1) ? (DATA_WIDTH - 1) : 0;
                        clk_counter <= settings.pulse_width;
                        parity_bit  <= 0;
                    end
                end

                /*-------------------------------------------------------------------------------
                    Режим DATA:
                    В соответствии с тактами UART отправляет данные. Порядок отправки данных
                    (от старшего / от младшего) определяется значением settings.seniority_h.
                    В качестве индекса бита выступает переменная bit_counter, которая
                    инкрементируется или декрементируется в зависимости от параметра
                    tx.seniority_h.

                    Параллельно с отправкой вычисляется бит четности (parity_bit) - если 
                    встречается единица, то резутьтат складывается по модулю двойки (xor).

                    Когда все данные приняты, автомат переходит в состояние PARITY или STOP
                    (в зависимости от параметра parity_on).
                -------------------------------------------------------------------------------*/
                DATA: begin
                    if (clk_counter > 0) begin
                        clk_counter <= clk_counter - 1;
                    end
                    else begin
                        tx.signal   <= buffer[bit_counter];
                        clk_counter <= settings.pulse_width;

                        if (settings.parity_on == 1) parity_bit <= parity_bit ^ buffer[bit_counter];

                        if (check_end_of_message()) begin
                            if (settings.parity_on == 1) state <= PARITY;
                            else state <= STOP;
                        end
                        else begin
                            bit_counter <= bit_counter + (settings.seniority_h ? -1 : 1);
                        end
                    end
                end

                /*-------------------------------------------------------------------------------
                    Режим PARITY:
                    Добавляет бит четности в конец передаваемого сообщения (parity_bit),
                    после чего переходит в состояние STOP.
                -------------------------------------------------------------------------------*/
                PARITY: begin
                    if (clk_counter > 0) begin
                        clk_counter <= clk_counter - 1;
                    end
                    else begin
                        tx.signal   <= parity_bit ^ settings.parity_set;
                        state       <= STOP;
                        clk_counter <= settings.pulse_width;
                    end
                end

                /*-------------------------------------------------------------------------------
                    Режим STOP:
                    С помощью процедуры add_stop_bit() вычитывается количество тактов UART,
                    которое будет отведено на стоповый бит (количество тактов зависит от
                    сохраненного при настройке параметра settings.sbl).
                    После добавления стопового бита, атомат возварщается в состояние IDLE.
                -------------------------------------------------------------------------------*/
                STOP: begin
                    if (clk_counter > 0) begin
                        clk_counter <= clk_counter - 1;
                    end
                    else begin
                        state     <= IDLE;
                        tx.signal <= 1;
                        add_stop_bit();
                    end
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    task add_stop_bit();  // Процедура добавления длинны стопового бита
        case (settings.sbl)
            ONE: clk_counter          <= settings.pulse_width;
            
            TWO: clk_counter          <= (settings.pulse_width << 1);

            ONE_AND_HALF: clk_counter <= settings.pulse_width + (settings.pulse_width >> 1);

            default: clk_counter      <= settings.pulse_width + (settings.pulse_width >> 1);
        endcase
    endtask

    function bit check_end_of_message();  // Проверка конца сообщения с учетом порядка вывода битов
        if (((bit_counter == DATA_WIDTH - 1) & (~settings.seniority_h)) || ((bit_counter == 0) & (settings.seniority_h))) begin
            return 1; 
        end
        return 0;
    endfunction

endmodule
`endif