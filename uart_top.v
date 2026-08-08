// Code your design here
module tx_fifo #(
    parameter DATA_WIDTH = 8,
    parameter DEPTH      = 16,
    parameter ADDR_WIDTH = 4          // log2(DEPTH)
)(
    input                       clk,
    input                       rst,

    // Write Interface
    input                       wr_en,
    input  [DATA_WIDTH-1:0]     data_in,

    // Read Interface
    input                       rd_en,
    output reg [DATA_WIDTH-1:0] data_out,

    // Status
    output                      full,
    output                      empty
);

    // FIFO Memory
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    // Pointers
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    // Number of stored words
    reg [ADDR_WIDTH:0] count;

    //-----------------------------
    // Write / Read Logic
    //-----------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            wr_ptr   <= 0;
            rd_ptr   <= 0;
            count    <= 0;
            data_out <= 0;
        end
        else begin

            //-------------------------
            // Write
            //-------------------------
            if (wr_en && !full) begin
                mem[wr_ptr] <= data_in;
                wr_ptr <= wr_ptr + 1;
            end

            //-------------------------
            // Read
            //-------------------------
            if (rd_en && !empty) begin
                data_out <= mem[rd_ptr];
                rd_ptr <= rd_ptr + 1;
            end

            //-------------------------
            // Count Update
            //-------------------------
            case ({wr_en && !full, rd_en && !empty})

                2'b10: count <= count + 1;   // Write only

                2'b01: count <= count - 1;   // Read only

                default: count <= count;     // Both or Neither

            endcase

        end
    end

    //-----------------------------
    // Status Flags
    //-----------------------------
    assign full  = (count == DEPTH);

    assign empty = (count == 0);

endmodule
module uart_tx(
    input        clk,
    input        rst,

    input        baud_tick,
    input        tx_start,
    input  [7:0] tx_data,

    output reg   tx_serial,
    output reg   busy,
    output reg   done
);

    //-----------------------------
    // FSM States
    //-----------------------------
    localparam IDLE  = 2'b00,
               START = 2'b01,
               DATA  = 2'b10,
               STOP  = 2'b11;

    reg [1:0] state;
    reg [7:0] shift_reg;
    reg [2:0] bit_count;

    always @(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            state      <= IDLE;
            tx_serial  <= 1'b1;
            busy       <= 1'b0;
            done       <= 1'b0;
            bit_count  <= 3'd0;
            shift_reg  <= 8'd0;
        end
        else
        begin

            // done is a one-clock pulse
            done <= 1'b0;

            case(state)

            //-----------------------------------
            // IDLE
            //-----------------------------------
            IDLE:
            begin
                tx_serial <= 1'b1;
                busy <= 1'b0;

                if(tx_start)
                begin
                    shift_reg <= tx_data;
                    bit_count <= 3'd0;
                    busy <= 1'b1;
                    state <= START;
                end
            end

            //-----------------------------------
            // START BIT
            //-----------------------------------
            START:
            begin
                if(baud_tick)
                begin
                    tx_serial <= 1'b0;
                    state <= DATA;
                end
            end

            //-----------------------------------
            // DATA BITS
            //-----------------------------------
            DATA:
            begin
                if(baud_tick)
                begin
                    tx_serial <= shift_reg[0];
                    shift_reg <= shift_reg >> 1;

                    if(bit_count == 3'd7)
                        state <= STOP;
                    else
                        bit_count <= bit_count + 1;
                end
            end

            //-----------------------------------
            // STOP BIT
            //-----------------------------------
            STOP:
            begin
                if(baud_tick)
                begin
                    tx_serial <= 1'b1;
                    busy <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
            end

            endcase

        end
    end

endmodule
module uart_tx_top(

    input clk,
    input rst,
    input baud_tick,

    // User Interface
    input        wr_en,
    input  [7:0] data_in,

    output       tx_serial,

    output full,
    output empty

);

    //-----------------------------
    // Internal Signals
    //-----------------------------
    wire [7:0] fifo_data;

    reg rd_en;
    reg tx_start;

    wire busy;
    wire done;

    //-----------------------------
    // FIFO
    //-----------------------------
    tx_fifo fifo_inst(

        .clk(clk),
        .rst(rst),

        .wr_en(wr_en),
        .rd_en(rd_en),

        .data_in(data_in),
        .data_out(fifo_data),

        .full(full),
        .empty(empty)

    );

    //-----------------------------
    // UART TX
    //-----------------------------
    uart_tx uart_inst(

        .clk(clk),
        .rst(rst),

        .baud_tick(baud_tick),

        .tx_start(tx_start),
        .tx_data(fifo_data),

        .tx_serial(tx_serial),

        .busy(busy),
        .done(done)

    );

    //-----------------------------
    // Controller FSM
    //-----------------------------

    localparam IDLE      = 2'd0,
               READ_FIFO = 2'd1,
               START_TX  = 2'd2,
               WAIT_DONE = 2'd3;

    reg [1:0] state;

    always @(posedge clk or posedge rst)
    begin

        if(rst)
        begin

            state <= IDLE;

            rd_en <= 0;
            tx_start <= 0;

        end

        else
        begin

            // default values
            rd_en <= 0;
            tx_start <= 0;

            case(state)

            //----------------------------------
            // Wait for data
            //----------------------------------
            IDLE:
            begin

                if(!empty)
                    state <= READ_FIFO;

            end

            //----------------------------------
            // Read one byte from FIFO
            //----------------------------------
            READ_FIFO:
            begin

                rd_en <= 1;

                state <= START_TX;

            end

            //----------------------------------
            // Start UART
            //----------------------------------
            START_TX:
            begin

                tx_start <= 1;

                state <= WAIT_DONE;

            end

            //----------------------------------
            // Wait until UART finishes
            //----------------------------------
            WAIT_DONE:
            begin

                if(done)
                    state <= IDLE;

            end

            endcase

        end

    end

endmodule