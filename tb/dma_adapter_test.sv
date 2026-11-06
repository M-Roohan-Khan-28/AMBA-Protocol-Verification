`timescale 1ns/1ps
// Adapts the pinned corrected DMA bench to the separate reusable monitor.
// The DMA's independent byte-memory oracle remains in that source checkout.
module dma_adapter_test;
    tb_dma_portable base();
    int read_bursts,write_bursts,read_beats,write_beats,violations;
    axi4_burst_monitor #(.FATAL(1)) mon (
        .clk(base.aclk),.reset_n(base.aresetn),
        .awvalid(base.m_axi_awvalid),.awready(base.m_axi_awready),
        .wvalid(base.m_axi_wvalid),.wready(base.m_axi_wready),
        .bvalid(base.m_axi_bvalid),.bready(base.m_axi_bready),
        .arvalid(base.m_axi_arvalid),.arready(base.m_axi_arready),
        .rvalid(base.m_axi_rvalid),.rready(base.m_axi_rready),
        .awid(base.m_axi_awid),.bid(base.m_axi_bid),.arid(base.m_axi_arid),.rid(base.m_axi_rid),
        .awaddr(base.m_axi_awaddr),.araddr(base.m_axi_araddr),
        .awlen(base.m_axi_awlen),.arlen(base.m_axi_arlen),.wstrb(base.m_axi_wstrb),
        .awsize(base.m_axi_awsize),.arsize(base.m_axi_arsize),
        .awburst(base.m_axi_awburst),.arburst(base.m_axi_arburst),
        .bresp(base.m_axi_bresp),.rresp(base.m_axi_rresp),
        .wdata(base.m_axi_wdata),.rdata(base.m_axi_rdata),
        .wlast(base.m_axi_wlast),.rlast(base.m_axi_rlast),
        .read_bursts(read_bursts),.write_bursts(write_bursts),
        .read_beats(read_beats),.write_beats(write_beats),.violations(violations)
    );
endmodule
