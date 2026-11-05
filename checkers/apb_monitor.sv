`timescale 1ns/1ps
// Passive APB setup/access checker. No DUT internals or memory model inputs.
module apb_monitor #(
    parameter int ADDR_W = 8,
    parameter int DATA_W = 32
) (
    input logic clk, reset_n,
    input logic select, enable, write, ready, error,
    input logic [ADDR_W-1:0] addr,
    input logic [DATA_W-1:0] wdata,
    output int transfers,
    output int violations
);
    bit setup_seen;
    logic [ADDR_W-1:0] held_addr;
    logic [DATA_W-1:0] held_data;
    logic held_write;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            setup_seen <= 0;
            held_addr <= '0;
            held_data <= '0;
            held_write <= 0;
            transfers <= 0;
            violations <= 0;
        end else if (!select) begin
            if (enable) begin
                violations <= violations + 1;
                $display("APB_MONITOR_VIOLATION enable without select");
            end
            setup_seen <= 0;
        end else if (!enable) begin
            setup_seen <= 1;
            held_addr <= addr;
            held_write <= write;
            held_data <= wdata;
        end else begin
            if (!setup_seen || addr !== held_addr || write !== held_write ||
                (write && wdata !== held_data)) begin
                violations <= violations + 1;
                $display("APB_MONITOR_VIOLATION missing/unstable setup");
            end
            if (ready) begin
                transfers <= transfers + 1;
                setup_seen <= 0;
            end
        end
    end
endmodule
