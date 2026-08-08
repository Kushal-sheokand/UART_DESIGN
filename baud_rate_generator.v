`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07/27/2026 04:44:49 PM
// Design Name: 
// Module Name: baud_rate_generator
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module baud_generator (
    input  wire clk,
    input  wire rst,
    output reg  baud_tick,
    output reg  baud_tick16x
);

    //====================================================
    // Parameters
    //====================================================
    parameter CLK_FREQ = 50000000;
    parameter BAUD_RATE = 9600;

    localparam BAUD_DIV    = CLK_FREQ / BAUD_RATE;        // 5208
    localparam BAUD16_DIV  = CLK_FREQ / (BAUD_RATE * 16); // 325


    reg [15:0] baud_count;
    reg [15:0] baud16_count;

    //====================================================
    // Baud Generator
    //====================================================
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            baud_count   <= 0;
            baud16_count <= 0;
            baud_tick    <= 0;
            baud_tick16x <= 0;
        end
        else
        begin
            //------------------------------------------------
            // Generate 1x Baud Tick
            //------------------------------------------------
            if (baud_count == BAUD_DIV-1)
            begin
                baud_count <= 0;
                baud_tick  <= 1'b1;
            end
            else
            begin
                baud_count <= baud_count + 1;
                baud_tick  <= 1'b0;
            end

            //------------------------------------------------
            // Generate 16x Baud Tick
            //------------------------------------------------
            if (baud16_count == BAUD16_DIV-1)
            begin
                baud16_count <= 0;
                baud_tick16x <= 1'b1;
            end
            else
            begin
                baud16_count <= baud16_count + 1;
                baud_tick16x <= 1'b0;
            end
        end
    end

endmodule