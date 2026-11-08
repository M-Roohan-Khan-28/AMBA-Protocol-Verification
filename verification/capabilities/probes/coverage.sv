`timescale 1ns/1ps
module probe_coverage;
  bit value;
  covergroup cg;
    option.per_instance=1;
    cp: coverpoint value { bins zero={0}; bins one={1}; }
  endgroup
  cg sampled;
  initial begin
    sampled=new();
    value=0; sampled.sample();
    value=1; sampled.sample();
    if (sampled.get_inst_coverage()<99.99) $fatal(1,"covergroup did not record samples");
    $display("FEATURE_PASS_coverage"); $finish;
  end
endmodule
