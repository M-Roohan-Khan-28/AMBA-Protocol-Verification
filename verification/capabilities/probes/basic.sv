`timescale 1ns/1ps
module probe_basic;
  logic [7:0] a, b, result;
  assign result = a + b;
  initial begin
    a=8'hfe; b=8'h03; #1;
    if (result !== 8'h01) $fatal(1,"basic SV arithmetic failed");
    $display("FEATURE_PASS_basic"); $finish;
  end
endmodule
