`timescale 1ns/1ps
module probe_classes_random;
  class transaction;
    rand bit [7:0] value;
    constraint bounded { value inside {[8'd4:8'd19]}; }
  endclass
  transaction item;
  initial begin
    item=new(); item.srandom(32'h28a6beef);
    repeat(32) begin
      if (!item.randomize()) $fatal(1,"constraint solver failed");
      if (item.value<4 || item.value>19) $fatal(1,"constraint was not enforced");
    end
    $display("FEATURE_PASS_classes_random"); $finish;
  end
endmodule
