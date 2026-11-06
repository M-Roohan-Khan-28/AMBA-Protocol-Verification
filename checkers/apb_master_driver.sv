`timescale 1ns/1ps
// Reusable portable APB transaction driver; observations are returned to
// an independent adapter scoreboard.
module apb_master_driver (
    input logic clk, ready, error,
    input logic [31:0] rdata,
    output logic reset_n, select, enable, write,
    output logic [7:0] addr,
    output logic [31:0] wdata
);
    import amba_transactions::*;
    task automatic reset_bus(input int cycles);
        @(negedge clk);
        reset_n=0;select=0;enable=0;write=0;addr=0;wdata=0;
        repeat(cycles) @(negedge clk);
        reset_n=1;
    endtask
    task automatic issue(input apb_transaction_t tx, output apb_result_t result);
        @(negedge clk);
        select=1;enable=0;write=tx.write;addr=tx.addr;wdata=tx.data;
        @(negedge clk);
        enable=1;
        #1;
        while(ready !== 1'b1) begin
            @(negedge clk);
            #1;
        end
        result.error=error;result.data=rdata;
        @(negedge clk);
        select=0;enable=0;
    endtask
endmodule
