`timescale 1ns/1ps
module dma_uvm_top;
  import uvm_pkg::*;import dma_uvm_pkg::*;
  bit clk=0;always #5 clk=~clk;dma_bus bus(clk);
  dma_adapter adapter(bus);dma_assertions checker_i(bus);
  initial begin
    dma_config cfg;cfg=dma_config::type_id::create("cfg");cfg.vif=bus;cfg.scenario=dma_command::type_id::create("initial_case");
    void'($value$plusargs("FAULT=%s",cfg.fault));
    uvm_config_db#(dma_config)::set(null,"*","cfg",cfg);run_test("dma_test");
  end
  initial begin #20000000;$fatal(1,"DMA simulation global watchdog");end
endmodule
