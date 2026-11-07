`timescale 1ns/1ps
// Passive address/data phase accounting for a bounded AHB-Lite slave.
module ahb_lite_monitor (
    input logic clk, reset_n, select, ready, readyout, resp,
    input logic [7:0] addr,
    input logic [1:0] trans,
    input logic write,
    input logic [2:0] size,
    output int addresses,
    output int violations
);
    bit stalled, pending;
    logic [7:0] held_addr;
    logic [1:0] held_trans;
    logic held_write;
    logic [2:0] held_size;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            addresses <= 0; violations <= 0; stalled <= 0; pending <= 0;
            held_addr <= 0; held_trans <= 0; held_write <= 0; held_size <= 0;
        end else begin
            if (stalled && (addr !== held_addr || trans !== held_trans ||
                            write !== held_write || size !== held_size)) begin
                violations <= violations + 1;
                $display("AHB_MONITOR_VIOLATION address/control changed during stall");
            end
            stalled <= !ready;
            if (!ready) begin
                held_addr <= addr; held_trans <= trans;
                held_write <= write; held_size <= size;
            end
            if (ready && readyout && select && trans[1]) begin
                addresses <= addresses + 1;
                pending <= 1;
            end else if (ready && readyout) pending <= 0;
            if (resp && !pending) begin
                violations <= violations + 1;
                $display("AHB_MONITOR_VIOLATION response without data phase");
            end
            // readyout may be fixed high for the selected educational DUT.
        end
    end
endmodule
