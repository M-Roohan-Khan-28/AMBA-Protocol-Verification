`timescale 1ns/1ps
module axi_lite_response_negative;
  logic clk=0;
  always #5 clk=~clk;
  logic reset_n=0,awvalid=0,awready=0,wvalid=0,wready=0,bvalid=0,bready=0;
  logic arvalid=0,arready=0,rvalid=0,rready=0;
  logic [31:0] awaddr=0,wdata=0,araddr=0,rdata=0;
  logic [3:0] wstrb=4'hf;
  logic [1:0] bresp=0,rresp=0;
  int aw_count,w_count,b_count,ar_count,r_count,violations;
  axi_lite_monitor mon(.*);
  initial begin
    repeat(2) @(negedge clk);
    reset_n=1; bvalid=1; bready=0;
    repeat(3) @(negedge clk);
    if(violations<3) $fatal(1,"held early BVALID escaped under backpressure");

    reset_n=0; bvalid=0;
    repeat(2) @(negedge clk);
    reset_n=1; rvalid=1; rready=0;
    repeat(3) @(negedge clk);
    if(violations<3) $fatal(1,"held early RVALID escaped under backpressure");

    reset_n=0; rvalid=0;
    repeat(2) @(negedge clk);
    reset_n=1; awvalid=1; awready=1; wvalid=1; wready=1;
    bvalid=1; bready=0; arvalid=1; arready=1; rvalid=1; rready=0;
    @(negedge clk);
    if(violations<2) $fatal(1,"same-edge B/R dependencies escaped");
    $display("AMBA_AXIL_RESPONSE_NEGATIVE_PASS scenarios=4 violations=%0d",violations);
    $finish;
  end
  initial begin #10000; $fatal(1,"AXIL response negative watchdog"); end
endmodule
