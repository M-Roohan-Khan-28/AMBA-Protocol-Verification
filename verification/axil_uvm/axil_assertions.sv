`timescale 1ns/1ps
module axil_assertions(axil_bus b);
  logic aw_seen=0,w_seen=0,ar_seen=0;
  // Nonblocking updates ensure properties see prior-edge acceptance state.
  always @(posedge b.clk) begin
    if(!b.reset_n) begin aw_seen<=0;w_seen<=0;ar_seen<=0;end
    else begin
      if(b.bvalid&&b.bready) begin aw_seen<=0;w_seen<=0;end
      if(b.rvalid&&b.rready) ar_seen<=0;
      if(b.awvalid&&b.awready) aw_seen<=1;
      if(b.wvalid&&b.wready) w_seen<=1;
      if(b.arvalid&&b.arready) ar_seen<=1;
    end
  end
  task automatic violation(string id);
    b.assertion_failures++;
    $display("AXIL_ASSERT_DETECTED %s time=%0t",id,$time);
    if(!$test$plusargs("EXPECT_ASSERT")) $fatal(1,"AXI4-Lite assertion %s",id);
  endtask
  a_aw: assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.awvalid&&!b.awready |=> b.awvalid&&$stable({b.awaddr,b.awprot})) else violation("AW_HOLD");
  a_w: assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.wvalid&&!b.wready |=> b.wvalid&&$stable({b.wdata,b.wstrb})) else violation("W_HOLD");
  a_ar: assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.arvalid&&!b.arready |=> b.arvalid&&$stable({b.araddr,b.arprot})) else violation("AR_HOLD");
  a_b: assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.bvalid&&!b.bready |=> b.bvalid&&$stable(b.bresp)) else violation("B_HOLD");
  a_r: assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.rvalid&&!b.rready |=> b.rvalid&&$stable({b.rdata,b.rresp})) else violation("R_HOLD");
  // VALID eligibility is checked even when the recipient's READY is low.
  a_b_dependency: assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.bvalid |-> aw_seen&&w_seen) else violation("B_ELIGIBILITY");
  a_r_dependency: assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.rvalid |-> ar_seen) else violation("R_ELIGIBILITY");
endmodule
