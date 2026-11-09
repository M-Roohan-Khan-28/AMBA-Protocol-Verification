`timescale 1ns/1ps
// Unmodified locked RTL. Fault switches modify only verification boundary pins.
module axil_adapter #(parameter int ADAPTER=0)(axil_bus b);
  bit fault_data,fault_address;
  initial begin fault_data=$test$plusargs("FAULT_DATA");fault_address=$test$plusargs("FAULT_ADDRESS");end
  if(ADAPTER==0) begin: slave_target
    axi_lite_if n(b.clk,b.reset_n);
    logic en,we;logic[3:0] addr,strb;logic[31:0] wd,rd;
    assign n.awaddr=b.awaddr;assign n.awprot=b.awprot;assign n.awvalid=b.awvalid;
    assign n.wdata=b.wdata;assign n.wstrb=b.wstrb;assign n.wvalid=b.wvalid;
    assign n.bready=b.bready;assign n.araddr=b.araddr;assign n.arprot=b.arprot;assign n.arvalid=b.arvalid;assign n.rready=b.rready;
    assign b.awready=n.awready;assign b.wready=n.wready;assign b.bvalid=n.bvalid;assign b.bresp=n.bresp;
    assign b.arready=n.arready;assign b.rvalid=n.rvalid;assign b.rresp=n.rresp;
    assign b.rdata=n.rdata ^ (fault_data ? 32'b1 : 32'b0);
    axi_lite_slave #(.SRAM_DEPTH(16)) dut(n,en,we,addr,wd,strb,rd);
    sram #(.DEPTH(16)) memory(b.clk,b.reset_n,en,we,addr,wd,strb,rd);
  end else if(ADAPTER==1) begin: master_target
    axi_lite_if n(b.clk,b.reset_n);
    axi_lite_master dut(.clk(b.clk),.reset_n(b.reset_n),.req_valid(b.req_valid),.req_write(b.req_write),
      .req_addr(b.req_addr),.req_wdata(b.req_wdata),.req_wstrb(b.req_wstrb),.req_ready(b.req_ready),
      .response_valid(b.response_valid),.response_error(b.response_error),.response_data(b.response_data),.axi(n));
    assign b.awaddr=n.awaddr ^ (fault_address ? 32'h4 : 32'h0);assign b.awprot=n.awprot;assign b.awvalid=n.awvalid;
    assign b.wdata=n.wdata;assign b.wstrb=n.wstrb;assign b.wvalid=n.wvalid;assign b.bready=n.bready;
    assign b.araddr=n.araddr;assign b.arprot=n.arprot;assign b.arvalid=n.arvalid;assign b.rready=n.rready;
    assign n.awready=b.awready;assign n.wready=b.wready;assign n.bvalid=b.bvalid;assign n.bresp=b.bresp;
    assign n.arready=b.arready;assign n.rvalid=b.rvalid;assign n.rresp=b.rresp;
    assign n.rdata=b.rdata ^ (fault_data ? 32'b1 : 32'b0);
  end else begin: integrated_target
    logic[31:0] rd;
    axi4_lite_memory_top #(.SRAM_DEPTH(16)) dut(.clk(b.clk),.reset_n(b.reset_n),
      .req_valid(b.req_valid),.req_write(b.req_write),.req_addr(b.req_addr),.req_wdata(b.req_wdata),.req_wstrb(b.req_wstrb),
      .req_ready(b.req_ready),.response_valid(b.response_valid),.response_error(b.response_error),.response_data(rd));
    assign b.response_data=rd ^ (fault_data ? 32'b1 : 32'b0);
    // Observe the integration's public bus pins; never inspect DUT memory/state.
    assign b.awaddr=dut.bus.awaddr;assign b.awprot=dut.bus.awprot;assign b.awvalid=dut.bus.awvalid;assign b.awready=dut.bus.awready;
    assign b.wdata=dut.bus.wdata;assign b.wstrb=dut.bus.wstrb;assign b.wvalid=dut.bus.wvalid;assign b.wready=dut.bus.wready;
    assign b.bvalid=dut.bus.bvalid;assign b.bready=dut.bus.bready;assign b.bresp=dut.bus.bresp;
    assign b.araddr=dut.bus.araddr;assign b.arprot=dut.bus.arprot;assign b.arvalid=dut.bus.arvalid;assign b.arready=dut.bus.arready;
    assign b.rvalid=dut.bus.rvalid;assign b.rready=dut.bus.rready;assign b.rresp=dut.bus.rresp;assign b.rdata=dut.bus.rdata;
  end
endmodule
