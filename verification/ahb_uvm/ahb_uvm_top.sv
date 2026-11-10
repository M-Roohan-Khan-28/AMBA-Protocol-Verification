`timescale 1ns/1ps
module ahb_uvm_top;
  import uvm_pkg::*;import ahb_uvm_pkg::*;
  logic clk=0;always #5 clk=~clk;
  ahb_bus bus(clk);
  // A controlled global stall is distinct from the slave's local readiness.
  assign bus.ready=bus.ext_ready&&bus.readyout;
  ahb_lite_slave_ram dut(.HCLK(clk),.HRESETn(bus.reset_n),.HSEL(bus.sel),.HADDR(bus.addr),.HTRANS(bus.trans),.HWRITE(bus.write),.HSIZE(bus.size),.HWDATA(bus.wdata),.HREADY(bus.ready),.HRDATA(bus.rdata),.HREADYOUT(bus.readyout),.HRESP(bus.resp));
  ahb_assertions assertions_i(bus);
  initial begin uvm_config_db#(virtual ahb_bus)::set(null,"uvm_test_top","vif",bus);run_test("ahb_test");end
  initial begin #1000000;$fatal(1,"AHB_PROGRESS_TIMEOUT");end
endmodule
