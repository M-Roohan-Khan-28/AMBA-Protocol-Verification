`timescale 1ns/1ps
// Reusable request-side driver for a one-outstanding AXI4-Lite master.
module axi_lite_request_driver (
    input logic clk, req_ready, response_valid, response_error,
    input logic [31:0] response_data,
    output logic req_valid, req_write,
    output logic [31:0] req_addr, req_wdata,
    output logic [3:0] req_wstrb
);
    import amba_transactions::*;
    initial begin
        req_valid=0;req_write=0;req_addr=0;req_wdata=0;req_wstrb=0;
    end
    task automatic issue(input axi_lite_transaction_t tx,
                         output axi_lite_result_t result);
        @(negedge clk);
        while(!req_ready) @(negedge clk);
        req_valid=1;req_write=tx.write;req_addr=tx.addr;
        req_wdata=tx.data;req_wstrb=tx.strb;
        @(negedge clk);req_valid=0;
        while(!response_valid) @(negedge clk);
        result.error=response_error;result.data=response_data;
    endtask
endmodule
