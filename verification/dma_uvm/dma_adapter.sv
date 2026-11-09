`timescale 1ns/1ps
module dma_adapter(dma_bus b);
  wire [31:0] actual_araddr,actual_awaddr; wire [63:0] actual_wdata; wire[7:0] actual_wstrb;
  wire actual_arvalid,actual_awvalid,actual_wvalid;
  string fault; initial if(!$value$plusargs("FAULT=%s",fault)) fault="none";
  assign b.d_araddr=actual_araddr ^ ((fault=="source_alias")?32'h100:0);
  assign b.d_awaddr=actual_awaddr ^ ((fault=="destination_progress")?32'h100:0);
  // Legal test-only transform: disabled byte lanes have no memory effect.
  // Constant mode + unchanged WSTRB/payload makes this stable throughout stalls.
  bit inactive_lanes; initial inactive_lanes=$test$plusargs("INACTIVE_LANES");
  wire [63:0] lane_xor;
  for(genvar lane=0;lane<8;lane++)begin: inactive_transform
    assign lane_xor[8*lane+:8]=(inactive_lanes&&!actual_wstrb[lane])?8'hff:8'h00;
  end
  assign b.d_wdata=actual_wdata ^ lane_xor ^ ((fault=="active_data")?64'h1:0);
  assign b.d_wstrb=(fault=="tail_strobe" && actual_wstrb!=255)?8'hff:actual_wstrb;
  assign b.d_arvalid=actual_arvalid || (fault=="duplicate_read" && b.irq);
  assign b.d_awvalid=actual_awvalid || (fault=="duplicate_write" && b.irq);
  assign b.d_wvalid=actual_wvalid || (fault=="duplicate_write" && b.irq);
  always @(posedge b.clk)if(b.reset_n&&inactive_lanes&&b.d_wvalid&&b.d_wready&&actual_wstrb!=255)begin
    for(int lane=0;lane<8;lane++)begin
      if(actual_wstrb[lane])assert(b.d_wdata[8*lane+:8]===actual_wdata[8*lane+:8])else $fatal(1,"Inactive transform changed active data");
      else assert(b.d_wdata[8*lane+:8]===~actual_wdata[8*lane+:8])else $fatal(1,"Inactive transform missing");
    end
    $display("DMA_INACTIVE_ACCEPT mask=%h original=%h observed=%h",actual_wstrb,actual_wdata,b.d_wdata);
  end
  axi4_dma_subsystem dut(
    .aclk(b.clk),
    .aresetn(b.reset_n),
    .s_axil_awaddr(b.c_awaddr),
    .s_axil_awvalid(b.c_awvalid),
    .s_axil_awready(b.c_awready),
    .s_axil_wdata(b.c_wdata),
    .s_axil_wstrb(b.c_wstrb),
    .s_axil_wvalid(b.c_wvalid),
    .s_axil_wready(b.c_wready),
    .s_axil_bresp(b.c_bresp),
    .s_axil_bvalid(b.c_bvalid),
    .s_axil_bready(b.c_bready),
    .s_axil_araddr(b.c_araddr),
    .s_axil_arvalid(b.c_arvalid),
    .s_axil_arready(b.c_arready),
    .s_axil_rdata(b.c_rdata),
    .s_axil_rresp(b.c_rresp),
    .s_axil_rvalid(b.c_rvalid),
    .s_axil_rready(b.c_rready),
    .irq(b.irq),
    .m_axi_awid(b.d_awid),
    .m_axi_awaddr(actual_awaddr),
    .m_axi_awlen(b.d_awlen),
    .m_axi_awsize(b.d_awsize),
    .m_axi_awburst(b.d_awburst),
    .m_axi_awvalid(actual_awvalid),
    .m_axi_awready(b.d_awready),
    .m_axi_wdata(actual_wdata),
    .m_axi_wstrb(actual_wstrb),
    .m_axi_wlast(b.d_wlast),
    .m_axi_wvalid(actual_wvalid),
    .m_axi_wready(b.d_wready),
    .m_axi_bid(b.d_bid),
    .m_axi_bresp(b.d_bresp),
    .m_axi_bvalid(b.d_bvalid),
    .m_axi_bready(b.d_bready),
    .m_axi_arid(b.d_arid),
    .m_axi_araddr(actual_araddr),
    .m_axi_arlen(b.d_arlen),
    .m_axi_arsize(b.d_arsize),
    .m_axi_arburst(b.d_arburst),
    .m_axi_arvalid(actual_arvalid),
    .m_axi_arready(b.d_arready),
    .m_axi_rid(b.d_rid),
    .m_axi_rdata(b.d_rdata),
    .m_axi_rresp(b.d_rresp),
    .m_axi_rlast(b.d_rlast),
    .m_axi_rvalid(b.d_rvalid),
    .m_axi_rready(b.d_rready)
  );
endmodule
