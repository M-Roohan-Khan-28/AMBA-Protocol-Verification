`timescale 1ns/1ps
// ARM IHI 0033A sections 3.6, 5.1 and 6.1; endpoint checks explicitly EP_.
module ahb_assertions(ahb_bus b);
  bit pending=0,pwrite=0,error_started=0;
  string expected="";bit reported[string];
  initial void'($value$plusargs("EXPECT_SVA=%s",expected));
  task automatic violation(string id);
    if(!reported.exists(id))begin reported[id]=1;b.sva_count++;$display("AHB_SVA_DETECTED %s time=%0t",id,$time);end
    if(id!=expected)$fatal(1,"AHB_SVA_UNEXPECTED %s",id);
  endtask
  // NBA updates preserve pre-edge ownership for concurrent properties.
  always @(posedge b.clk or negedge b.reset_n)begin
    if(!b.reset_n)begin pending<=0;pwrite<=0;error_started<=0;end
    else begin
      if(b.ready)begin pending<=b.sel&&b.trans[1];pwrite<=b.write;error_started<=0;end
      if(b.resp&&!b.readyout)error_started<=1;
    end
  end
  // A waited active address must hold; a preceding ERROR permits cancellation.
  a_address:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    !b.ready&&b.trans[1]&&!b.resp |=> $stable({b.sel,b.trans,b.addr,b.size,b.write}))else violation("ADDRESS_HOLD");
  // IDLE may remain IDLE/change address, or advance to NONSEQ, not BUSY/SEQ.
  a_idle:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    !b.ready&&b.trans==0&&!b.resp |=> b.trans==0||b.trans==2)else violation("IDLE_TRANSITION");
  // BUSY wait exceptions are qualified for an undefined-length sequence (no HBURST port).
  a_busy:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    !b.ready&&b.trans==1&&!b.resp |=> (b.trans==0||b.trans==2)||
      $stable({b.addr,b.write,b.size}))else violation("BUSY_CONTROL");
  a_data:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    pending&&pwrite&&!b.ready |=> $stable(b.wdata))else violation("WRITE_DATA_HOLD");
  a_owner:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    b.resp |-> pending)else violation("RESPONSE_OWNER");
  a_error_first:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    b.resp&&b.readyout |-> error_started)else violation("ERROR_FIRST");
  a_error_next:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    b.resp&&!b.readyout |=> b.resp&&b.readyout)else violation("ERROR_SECOND");
  a_error_hold:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    b.resp&&b.readyout&&!b.ready |=> b.resp&&b.readyout)else violation("ERROR_HOLD");
  ep_ready:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    !b.resp |-> b.readyout)else violation("EP_ZERO_WAIT");
  ep_global:assert property(@(posedge b.clk)disable iff(!b.reset_n)
    b.ready |-> b.readyout)else violation("GLOBAL_READY");
  ep_reset:assert property(@(posedge b.clk) !b.reset_n |-> !b.resp&&b.readyout&&b.rdata==0)else violation("EP_RESET");
endmodule
