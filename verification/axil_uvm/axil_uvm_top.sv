`timescale 1ns/1ps
module axil_uvm_top;
  import uvm_pkg::*;import axil_uvm_pkg::*;
  bit clk=0;always #5 clk=~clk;
  axil_bus bus(clk);
  axil_adapter #(.ADAPTER(`AXIL_ADAPTER)) adapter(bus);
  axil_assertions assertions(bus);
  initial begin
    if(`AXIL_ADAPTER==0)begin
      bus.awaddr=0;bus.awprot=0;bus.awvalid=0;bus.wdata=0;bus.wstrb=0;bus.wvalid=0;
      bus.bready=0;bus.araddr=0;bus.arprot=0;bus.arvalid=0;bus.rready=0;
    end else begin
      bus.req_valid=0;bus.req_write=0;bus.req_addr=0;bus.req_wdata=0;bus.req_wstrb=0;
    end
    if(`AXIL_ADAPTER==1)begin
      bus.awready=0;bus.wready=0;bus.bvalid=0;bus.bresp=0;
      bus.arready=0;bus.rvalid=0;bus.rresp=0;bus.rdata=0;
    end
  end
  initial begin
    axil_config cfg;
    cfg=axil_config::type_id::create("cfg");
    cfg.adapter=`AXIL_ADAPTER;cfg.vif=bus;
    uvm_config_db#(axil_config)::set(null,"*","cfg",cfg);
    run_test("axil_test");
  end
  initial begin #1000000;$fatal(1,"AXI4-Lite UVM simulation watchdog");end
endmodule
