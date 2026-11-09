`timescale 1ns/1ps
module dma_assertions(dma_bus b);
  bit aw_seen=0, ar_seen=0, w_end=0, ca=0,cw=0,cr=0;
  int unsigned wn=0,rn=0,alen=0,rlen=0;
  string expected=""; bit reported[string];
  initial void'($value$plusargs("EXPECT_SVA=%s",expected));
  task automatic violation(string id);
    if(!reported.exists(id)) begin
      reported[id]=1;b.sva_count++;
      $display("DMA_SVA_DETECTED %s time=%0t",id,$time);
    end
    if(id!=expected) $fatal(1,"DMA_SVA_UNEXPECTED %s",id);
  endtask
  // State updated nonblocking: assertions consume prior-edge handshakes.
  always @(posedge b.clk) begin
    if(!b.reset_n) begin
      aw_seen<=0;ar_seen<=0;w_end<=0;wn<=0;rn<=0;alen<=0;rlen<=0;ca<=0;cw<=0;cr<=0;
    end else begin
      if(b.d_bvalid&&b.d_bready)begin aw_seen<=0;w_end<=0;wn<=0;end
      if(b.d_rvalid&&b.d_rready)begin rn<=rn+1;if(b.d_rlast||rn==rlen)ar_seen<=0;end
      if(b.d_awvalid&&b.d_awready)begin aw_seen<=1;alen<=b.d_awlen;end
      if(b.d_wvalid&&b.d_wready)begin wn<=wn+1;if(b.d_wlast)w_end<=1;end
      if(b.d_arvalid&&b.d_arready)begin ar_seen<=1;rlen<=b.d_arlen;rn<=0;end
      if(b.c_bvalid&&b.c_bready)begin ca<=0;cw<=0;end
      if(b.c_awvalid&&b.c_awready)ca<=1;
      if(b.c_wvalid&&b.c_wready)cw<=1;
      if(b.c_rvalid&&b.c_rready)cr<=0;
      if(b.c_arvalid&&b.c_arready)cr<=1;
    end
  end
  a_aw:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_awvalid&&!b.d_awready |=> b.d_awvalid&&$stable({b.d_awid,b.d_awaddr,b.d_awlen,b.d_awsize,b.d_awburst}))else violation("AW_HOLD");
  a_w:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_wvalid&&!b.d_wready |=> b.d_wvalid&&$stable({b.d_wdata,b.d_wstrb,b.d_wlast}))else violation("W_HOLD");
  a_ar:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_arvalid&&!b.d_arready |=> b.d_arvalid&&$stable({b.d_arid,b.d_araddr,b.d_arlen,b.d_arsize,b.d_arburst}))else violation("AR_HOLD");
  a_b:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_bvalid&&!b.d_bready |=> b.d_bvalid&&$stable({b.d_bid,b.d_bresp}))else violation("B_HOLD");
  a_r:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_rvalid&&!b.d_rready |=> b.d_rvalid&&$stable({b.d_rid,b.d_rdata,b.d_rresp,b.d_rlast}))else violation("R_HOLD");
  a_be:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_bvalid |-> aw_seen&&w_end)else violation("B_ELIGIBILITY");
  a_re:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_rvalid |-> ar_seen)else violation("R_ELIGIBILITY");
  a_awa:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_awvalid |-> b.d_awid==0&&b.d_awsize==3&&b.d_awburst==1&&b.d_awlen<16&&b.d_awaddr[2:0]==0&&({1'b0,b.d_awaddr[11:0]}+((b.d_awlen+13'd1)<<3)<=4096))else violation("AW_ATTR");
  a_ara:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_arvalid |-> b.d_arid==0&&b.d_arsize==3&&b.d_arburst==1&&b.d_arlen<16&&b.d_araddr[2:0]==0&&({1'b0,b.d_araddr[11:0]}+((b.d_arlen+13'd1)<<3)<=4096))else violation("AR_ATTR");
  a_wl:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_wvalid&&b.d_wready |-> !w_end&&wn<16&&(!aw_seen||(b.d_wlast==(wn==alen))))else violation("W_LAST");
  a_early_w:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_awvalid&&b.d_awready&&w_end |-> wn==b.d_awlen+1)else violation("W_LAST");
  a_rl:assert property(@(posedge b.clk) disable iff(!b.reset_n)
    b.d_rvalid&&ar_seen |-> b.d_rlast==(rn==rlen))else violation("R_LAST");
  a_rid:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.d_rvalid |-> b.d_rid==0)else violation("R_ID");
  a_bid:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.d_bvalid |-> b.d_bid==0)else violation("B_ID");
  c_a:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.c_awvalid&&!b.c_awready |=> b.c_awvalid&&$stable(b.c_awaddr))else violation("C_AW_HOLD");
  c_w:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.c_wvalid&&!b.c_wready |=> b.c_wvalid&&$stable({b.c_wdata,b.c_wstrb}))else violation("C_W_HOLD");
  c_ar:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.c_arvalid&&!b.c_arready |=> b.c_arvalid&&$stable(b.c_araddr))else violation("C_AR_HOLD");
  c_b:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.c_bvalid&&!b.c_bready |=> b.c_bvalid&&$stable(b.c_bresp))else violation("C_B_HOLD");
  c_r:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.c_rvalid&&!b.c_rready |=> b.c_rvalid&&$stable({b.c_rdata,b.c_rresp}))else violation("C_R_HOLD");
  c_be:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.c_bvalid |-> ca&&cw)else violation("C_B_ELIGIBILITY");
  c_re:assert property(@(posedge b.clk) disable iff(!b.reset_n) b.c_rvalid |-> cr)else violation("C_R_ELIGIBILITY");
endmodule
