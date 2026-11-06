`timescale 1ns/1ps
// Reusable single-transfer driver for this bounded word-access AHB-Lite DUT.
module ahb_lite_master_driver (
    input logic clk, readyout, resp,
    input logic [31:0] rdata,
    output logic select, write,
    output logic [7:0] addr,
    output logic [1:0] trans,
    output logic [2:0] size,
    output logic [31:0] wdata
);
    import amba_transactions::*;
    initial begin select=0;write=0;addr=0;trans=0;size=2;wdata=0; end
    task automatic issue(input ahb_transaction_t tx, output ahb_result_t result);
        @(negedge clk);
        select=1;trans=2'b10;write=tx.write;addr=tx.addr;size=tx.size;
        @(negedge clk);
        select=0;trans=0;write=0;wdata=tx.data;
        #1;
        if (!readyout) $fatal(1,"AHB driver requires zero-wait responder");
        result.error=resp; result.data=rdata;
        @(negedge clk);
        wdata=0;
    endtask
endmodule
