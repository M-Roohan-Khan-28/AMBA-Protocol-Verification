`timescale 1ns/1ps
module axi4_response_negative;
  logic clk=0;
  always #5 clk=~clk;
  logic reset_n=0,awvalid=0,awready=1,wvalid=0,wready=1,bvalid=0,bready=0;
  logic arvalid=0,arready=1,rvalid=0,rready=0,wlast=1,rlast=1;
  logic [3:0] awid=0,bid=0,arid=0,rid=0;
  logic [31:0] awaddr=0,araddr=0;
  logic [7:0] awlen=0,arlen=0,wstrb=8'hff;
  logic [2:0] awsize=3,arsize=3;
  logic [1:0] awburst=1,arburst=1,bresp=0,rresp=0;
  logic [63:0] wdata=0,rdata=0;
  int read_bursts,write_bursts,read_beats,write_beats,violations;
  axi4_burst_monitor #(.FATAL(0)) mon(.*);
  initial begin
    repeat(2) @(negedge clk);
    reset_n=1; awvalid=1;
    @(negedge clk); awvalid=0; bvalid=1; bready=0;
    repeat(3) @(negedge clk);
    if(violations!==3) $fatal(1,"held early AXI4 BVALID: expected 3 violations, got %0d",violations);
    $display("AXI4_NEGATIVE_CASE_PASS held_early_b");

    reset_n=0; bvalid=0;
    repeat(2) @(negedge clk);
    reset_n=1; rvalid=1; rready=0;
    repeat(3) @(negedge clk);
    if(violations!==3) $fatal(1,"held early AXI4 RVALID: expected 3 violations, got %0d",violations);
    $display("AXI4_NEGATIVE_CASE_PASS held_early_r");

    reset_n=0; rvalid=0;
    repeat(2) @(negedge clk);
    reset_n=1; awvalid=1; wvalid=1; bvalid=1; bready=0;
    // Isolate write dependency from the bounded monitor\'s read/write-overlap rule.
    arvalid=0; rvalid=0; rready=0;
    @(negedge clk);
    if(violations!==1) $fatal(1,"same-edge AXI4 B dependency: expected 1 violation, got %0d",violations);
    $display("AXI4_NEGATIVE_CASE_PASS same_edge_b");

    reset_n=0; awvalid=0; wvalid=0; bvalid=0;
    repeat(2) @(negedge clk);
    reset_n=1; arvalid=1; rvalid=1; rready=0;
    @(negedge clk);
    if(violations!==1) $fatal(1,"same-edge AXI4 R dependency: expected 1 violation, got %0d",violations);
    $display("AXI4_NEGATIVE_CASE_PASS same_edge_r");
    $display("AMBA_AXI4_RESPONSE_NEGATIVE_PASS scenarios=4 violations=%0d",violations);
    $finish;
  end
  initial begin #10000; $fatal(1,"AXI4 response negative watchdog"); end
endmodule
