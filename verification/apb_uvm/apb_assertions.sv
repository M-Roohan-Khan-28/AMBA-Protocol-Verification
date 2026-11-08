`timescale 1ns/1ps
// Assertions execute on pre-edge state, independent of UVM driver/scoreboard.
module apb_assertions(apb_bus b);
  logic past_valid=0;
  always @(posedge b.clk or negedge b.reset_n)
    if(!b.reset_n) past_valid<=0; else past_valid<=1;
  task automatic violation(input string id);
    b.assertion_failures++;
    $display("APB_ASSERT_DETECTED %s time=%0t",id,$time);
    // Controls allow exactly one named violation; all others are fatal.
    if(!$test$plusargs("EXPECT_ASSERT")) $fatal(1,"APB assertion %s",id);
  endtask
  a_setup: assert property (@(posedge b.clk) disable iff(!b.reset_n)
    b.select && !b.enable |=> b.select && b.enable &&
      $stable({b.write,b.addr}) && (!b.write || $stable(b.wdata))) else violation("SETUP");
  a_hold: assert property (@(posedge b.clk) disable iff(!b.reset_n)
    b.select && b.enable && !b.ready |=> b.select && b.enable &&
      $stable({b.write,b.addr}) && (!b.write || $stable(b.wdata))) else violation("WAIT_HOLD");
  a_access: assert property (@(posedge b.clk) disable iff(!b.reset_n)
    past_valid && b.select && b.enable |->
      $past(b.select && (!b.enable || !b.ready))) else violation("ACCESS_ENTRY");
  a_enable: assert property (@(posedge b.clk) disable iff(!b.reset_n)
    b.enable |-> b.select) else violation("ENABLE_SELECT");
  a_error: assert property (@(posedge b.clk) disable iff(!b.reset_n)
    b.error |-> b.select && b.enable && b.ready) else violation("ERROR_ELIGIBILITY");
endmodule
