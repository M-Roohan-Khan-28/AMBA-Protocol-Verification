`timescale 1ns/1ps
// ADAPTER 0: 64-word interface RAM; 1: four-word modport RAM;
// 2: synthetic wait/error responder (monitor/driver qualification only).
module apb_adapter #(parameter int ADAPTER=0)(apb_bus b);
  wire [31:0] native_rdata;
  if(ADAPTER==0) begin: interface_ram
`ifdef APB_INTERFACE_DUT
    apb_if native_bus(b.clk);
    assign native_bus.PRESETn=b.reset_n;
    assign native_bus.PSEL=b.select;
    assign native_bus.PENABLE=b.enable;
    assign native_bus.PWRITE=b.write;
    assign native_bus.PADDR=b.addr;
    assign native_bus.PWDATA=b.wdata;
    assign b.ready=native_bus.PREADY;
    assign b.error=native_bus.PSLVERR;
    assign native_rdata=native_bus.PRDATA;
    apb_ram dut(native_bus);
`endif
  end else if(ADAPTER==1) begin: modport_ram
`ifdef APB_MODPORT_DUT
    apb_if native_bus(b.clk,b.reset_n);
    assign native_bus.PSEL=b.select;
    assign native_bus.PENABLE=b.enable;
    assign native_bus.PWRITE=b.write;
    assign native_bus.PADDR=b.addr;
    assign native_bus.PWDATA=b.wdata;
    assign b.ready=native_bus.PREADY;
    assign b.error=native_bus.PSLVERR;
    assign native_rdata=native_bus.PRDATA;
    apb_slave_ram dut(native_bus);
`endif
  end else begin: synthetic_wait
    apb_ram_responder #(.WAIT_CYCLES(2),.WORDS(4),.ERROR_INDEX(3)) dut(
      .clk(b.clk),.reset_n(b.reset_n),.select(b.select),.enable(b.enable),
      .write(b.write),.addr(b.addr),.wdata(b.wdata),.ready(b.ready),
      .error(b.error),.rdata(native_rdata));
  end
  // Explicit runtime fault control, never changes the DUT or expected model.
  assign b.rdata=($test$plusargs("FAULT_READ") && b.select && b.enable &&
                   !b.write && b.addr==0) ? native_rdata^32'h1 : native_rdata;
endmodule
