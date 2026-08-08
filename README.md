UART Transceiver with FIFO Buffering (Verilog)

A parameterized UART transmitter and receiver design implemented in Verilog, featuring FIFO-buffered data paths and a 16x-oversampled receiver for robust asynchronous serial communication. Verified through RTL simulation in both Vivado XSim and Icarus Verilog.

Overview

This project implements a full UART (Universal Asynchronous Receiver/Transmitter) core consisting of:

Transmitter (uart_tx_top) — accepts parallel byte data via a FIFO interface and serializes it onto a single output line at a configurable baud rate.
Receiver (uart_rx_16x_top) — samples an incoming serial line using 16x oversampling for reliable bit-center detection, deserializes it back into bytes, and buffers the result in a FIFO for the user logic to read.
Baud Rate Generator (baud_generator) — derives both a 1x baud tick (for the transmitter) and a 16x baud tick (for the receiver) from a single system clock.

The design was verified using a self-checking loopback testbench that ties the transmitter's serial output directly into the receiver's serial input, sends known test bytes through the full pipeline, and automatically checks that every byte received matches what was sent.
Key Design Features
FIFO-buffered I/O on both TX and RX sides, allowing back-to-back byte transfers without blocking the user logic.
16x oversampling on receive — the receiver samples the incoming line 16 times per bit period and captures data at the bit center, giving tolerance to timing drift and short glitches on the serial line.
Start-bit re-qualification — the receiver double-checks the line is still low at the mid-point of the start bit before committing to a byte reception, rejecting short glitches.
2-stage input synchronizer on the receiver's serial input to reduce metastability risk from the asynchronous incoming signal.



Shared baud generator producing both 1x and 16x ticks from one clock, keeping TX and RX timing derived from a single source.

Sample Output

PASS: byte 0 expected=0xa5 received=0xa5

PASS: byte 1 expected=0x3c received=0x3c

PASS: byte 2 expected=0xff received=0xff

=== ALL TESTS PASSED ===
