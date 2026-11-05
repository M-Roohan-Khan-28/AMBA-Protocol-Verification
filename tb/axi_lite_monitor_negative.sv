`timescale 1ns/1ps
module axi_lite_monitor_negative;
    logic clk=0;
    always #5 clk=~clk;
    logic reset_n=0,awvalid=0,awready=0,wvalid=0,wready=0,bvalid=0,bready=0;
    logic arvalid=0,arready=0,rvalid=0,rready=0;
    logic [31:0] awaddr=0,wdata=0,araddr=0,rdata=0;
    logic [3:0] wstrb=0;
    logic [1:0] bresp=0,rresp=0;
    int aw_count,w_count,b_count,ar_count,r_count,violations;
    axi_lite_monitor mon(.*);
    initial begin
        repeat(2) @(negedge clk);
        reset_n=1; awvalid=1; awaddr=32'h100;
        @(negedge clk); awaddr=32'h104; // Address changed under AW backpressure.
        @(negedge clk); awvalid=0;
        repeat(2) @(negedge clk);
        if(violations<1) $fatal(1,"AXIL unstable-AW violation escaped");
        $display("AMBA_AXIL_NEGATIVE_PASS detected=%0d",violations);
        $finish;
    end
    initial begin #10000; $fatal(1,"AXIL negative watchdog"); end
endmodule
