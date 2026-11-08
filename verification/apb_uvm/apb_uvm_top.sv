`timescale 1ns/1ps
module apb_uvm_top;
  import uvm_pkg::*;
  import apb_uvm_pkg::*;
  bit clk=0;
  always #5 clk=~clk;
  apb_bus bus(clk);
  apb_adapter #(.ADAPTER(`APB_ADAPTER)) adapter(bus);
  apb_assertions assertions(bus);
  initial begin
    apb_config cfg;
    cfg=apb_config::type_id::create("cfg");
    cfg.adapter=`APB_ADAPTER; cfg.vif=bus;
    uvm_config_db#(apb_config)::set(null,"*","cfg",cfg);
    run_test("apb_deterministic_test");
  end
  initial begin #1000000; $fatal(1,"UVM wall-of-simulation watchdog"); end
endmodule
