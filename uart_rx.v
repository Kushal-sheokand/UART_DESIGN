// Code your design here
// UART RX with 16x oversampling
// baud_tick here must pulse 16 times per bit period (16x the baud rate),
// NOT once per bit period like the simple version.

module rx_fifo #(
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


module uart_rx_16x(
    input        clk,
    input        rst,

    input        baud_tick,   // ticks 16x per bit period
    input        rx_serial,

    output reg [7:0] rx_data,
    output reg       rx_done      // one-clock pulse when a byte is received
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
    reg [3:0] tick_count;   // counts 0..15 within a bit period

    // synchronize rx_serial to avoid metastability issues
    reg rx_sync_0, rx_sync_1;

    always @(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            rx_sync_0 <= 1'b1;
            rx_sync_1 <= 1'b1;
        end
        else
        begin
            rx_sync_0 <= rx_serial;
            rx_sync_1 <= rx_sync_0;
        end
    end

    always @(posedge clk or posedge rst)
    begin
        if(rst)
        begin
            state      <= IDLE;
            rx_data    <= 8'd0;
            rx_done    <= 1'b0;
            bit_count  <= 3'd0;
            tick_count <= 4'd0;
            shift_reg  <= 8'd0;
        end
        else
        begin

            // rx_done is a one-clock pulse
            rx_done <= 1'b0;

            case(state)

            //-----------------------------------
            // IDLE - wait for start bit (line goes low)
            //-----------------------------------
            IDLE:
            begin
                if(rx_sync_1 == 1'b0)
                begin
                    tick_count <= 4'd0;
                    state      <= START;
                end
            end

            //-----------------------------------
            // START BIT - sample at mid-bit (tick 7)
            // to confirm it's a real start bit, not a glitch
            //-----------------------------------
            START:
            begin
                if(baud_tick)
                begin
                    if(tick_count == 4'd7)
                    begin
                        if(rx_sync_1 == 1'b0)
                        begin
                            // confirmed start bit, reset counter for DATA
                            tick_count <= 4'd0;
                            bit_count  <= 3'd0;
                            state      <= DATA;
                        end
                        else
                        begin
                            // glitch - go back to idle
                            state <= IDLE;
                        end
                    end
                    else
                    begin
                        tick_count <= tick_count + 1;
                    end
                end
            end

            //-----------------------------------
            // DATA BITS - sample at mid-bit (tick 15) of each bit
            //-----------------------------------
            DATA:
            begin
                if(baud_tick)
                begin
                    if(tick_count == 4'd15)
                    begin
                        tick_count <= 4'd0;
                        shift_reg  <= {rx_sync_1, shift_reg[7:1]};

                        if(bit_count == 3'd7)
                            state <= STOP;
                        else
                            bit_count <= bit_count + 1;
                    end
                    else
                    begin
                        tick_count <= tick_count + 1;
                    end
                end
            end

            //-----------------------------------
            // STOP BIT - sample at mid-bit (tick 15)
            //-----------------------------------
            STOP:
            begin
                if(baud_tick)
                begin
                    if(tick_count == 4'd15)
                    begin
                        rx_data    <= shift_reg;
                        rx_done    <= 1'b1;
                        tick_count <= 4'd0;
                        state      <= IDLE;
                    end
                    else
                    begin
                        tick_count <= tick_count + 1;
                    end
                end
            end

            endcase

        end
    end

endmodule


module uart_rx_16x_top(

    input clk,
    input rst,
    input baud_tick,     // 16x oversampling tick

    // Serial Input
    input        rx_serial,

    // User Interface
    input        rd_en,
    output [7:0] data_out,

    output full,
    output empty

);

    //-----------------------------
    // Internal Signals
    //-----------------------------
    wire [7:0] rx_data;
    wire       rx_done;

    //-----------------------------
    // UART RX (16x oversampling)
    //-----------------------------
    uart_rx_16x uart_inst(

        .clk(clk),
        .rst(rst),

        .baud_tick(baud_tick),
        .rx_serial(rx_serial),

        .rx_data(rx_data),
        .rx_done(rx_done)

    );

    //-----------------------------
    // FIFO (reuse same rx_fifo module)
    //-----------------------------
    rx_fifo fifo_inst(

        .clk(clk),
        .rst(rst),

        .wr_en(rx_done),
        .data_in(rx_data),

        .rd_en(rd_en),
        .data_out(data_out),

        .full(full),
        .empty(empty)

    );

endmodule