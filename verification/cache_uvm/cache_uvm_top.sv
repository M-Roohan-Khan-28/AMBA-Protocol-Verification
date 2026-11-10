`timescale 1ns/1ps
module cache_uvm_top;
  import uvm_pkg::*;import cache_uvm_pkg::*;
  cache_bus bus();
  cache_2way dut(.clk(bus.clk),.reset(bus.reset),.write(bus.write),.tag(bus.tag),.index(bus.index),.data_in(bus.data_in),.way_select(bus.way_select),.data_out(bus.data_out),.hit(bus.hit));
  cache_assertions assertions(bus);
  initial begin uvm_config_db#(virtual cache_bus)::set(null,"*","vif",bus);run_test("cache_test");end
  initial begin #2000000;$fatal(1,"CACHE_PROGRESS_TIMEOUT");end
endmodule
