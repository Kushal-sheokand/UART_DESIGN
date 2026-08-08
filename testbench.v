`timescale 1ns / 1ps

module tb_uart_loopback;

    reg clk;
    reg rst;

    wire baud_tick;
    wire baud_tick16x;

    // TX side signals
    reg        tx_wr_en;
    reg  [7:0] tx_data_in;
    wire       tx_full;
    wire       tx_empty;
    wire       tx_serial;

    // RX side signals
    reg        rx_rd_en;
    wire [7:0] rx_data_out;
    wire       rx_full;
    wire       rx_empty;

    // Test bookkeeping
    reg [7:0] test_bytes [0:2];
    integer   i;
    reg [7:0] received_byte;
    integer   errors;

    //-----------------------------
    // Clock: 50 MHz -> 20 ns period
    //-----------------------------
    initial clk = 0;
    always #10 clk = ~clk;

    //-----------------------------
    // DUTs
    //-----------------------------
    baud_generator #(
        .CLK_FREQ(50000000),
        .BAUD_RATE(9600)
    ) baud_gen_inst (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick),
        .baud_tick16x(baud_tick16x)
    );

    uart_tx_top tx_inst (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick),
        .wr_en(tx_wr_en),
        .data_in(tx_data_in),
        .tx_serial(tx_serial),
        .full(tx_full),
        .empty(tx_empty)
    );

    uart_rx_16x_top rx_inst (
        .clk(clk),
        .rst(rst),
        .baud_tick(baud_tick16x),
        .rx_serial(tx_serial),      // loopback: TX output -> RX input
        .rd_en(rx_rd_en),
        .data_out(rx_data_out),
        .full(rx_full),
        .empty(rx_empty)
    );

    //-----------------------------
    // Stimulus
    //-----------------------------
    initial begin
        rst        = 1;
        tx_wr_en   = 0;
        tx_data_in = 8'h00;
        rx_rd_en   = 0;
        errors     = 0;

        test_bytes[0] = 8'hA5;
        test_bytes[1] = 8'h3C;
        test_bytes[2] = 8'hFF;

        repeat (5) @(posedge clk);
        rst = 0;
        repeat (5) @(posedge clk);

        //-------------------------------------------------
        // Push all 3 bytes into the TX FIFO back-to-back
        //-------------------------------------------------
        for (i = 0; i < 3; i = i + 1) begin
            @(posedge clk);
            tx_wr_en   = 1;
            tx_data_in = test_bytes[i];
            @(posedge clk);
            tx_wr_en   = 0;
        end

        //-------------------------------------------------
        // Wait for all 3 bytes to arrive in the RX FIFO
        //-------------------------------------------------
        for (i = 0; i < 3; i = i + 1) begin
            wait (!rx_empty);
            @(posedge clk);
            rx_rd_en = 1;
            @(posedge clk);
            rx_rd_en = 0;
            @(posedge clk); // data_out updates one cycle after rd_en
            received_byte = rx_data_out;

            if (received_byte === test_bytes[i]) begin
                $display("PASS: byte %0d expected=0x%02h received=0x%02h",
                          i, test_bytes[i], received_byte);
            end
            else begin
                $display("FAIL: byte %0d expected=0x%02h received=0x%02h",
                          i, test_bytes[i], received_byte);
                errors = errors + 1;
            end
        end

        repeat (50) @(posedge clk);

        if (errors == 0)
            $display("=== ALL TESTS PASSED ===");
        else
            $display("=== %0d TEST(S) FAILED ===", errors);

        $finish;
    end

    //-----------------------------
    // Safety timeout
    //-----------------------------
    initial begin
        #10000000; // 10 ms - plenty for 3 bytes at 9600 baud with 50MHz clock
        $display("ERROR: TIMEOUT - simulation did not finish");
        $finish;
    end

endmodule