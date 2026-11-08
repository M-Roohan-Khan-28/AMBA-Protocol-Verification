`timescale 1ns/1ps
module probe_sva;
  logic clk=0, reset_n=0, request=0, acknowledge=0;
  integer observed_failures=0;
  always #5 clk=~clk;
  property follows_request;
    @(posedge clk) disable iff (!reset_n) request |=> acknowledge;
  endproperty
  // An intentionally failing sample proves assertion execution is enabled.
  a_probe: assert property(follows_request) else begin
    observed_failures++;
    $display("EXPECTED_ASSERTION_FAILURE follows_request time=%0t", $time);
  end
  initial begin
    @(negedge clk); reset_n=1; request=1;
    @(negedge clk); request=0; acknowledge=1;
    @(negedge clk); request=1; acknowledge=0;
    @(negedge clk); request=0;
    @(negedge clk);
    if (observed_failures != 1) $fatal(1,"SVA did not execute exactly once");
    $display("FEATURE_PASS_sva"); $finish;
  end
  initial begin #1000; $fatal(1,"SVA probe watchdog"); end
endmodule
