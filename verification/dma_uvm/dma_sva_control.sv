`timescale 1ns/1ps
module dma_sva_control;
  bit clk=0;always #5 clk=~clk;dma_bus b(clk);dma_assertions checker_i(b);
  string scenario,expected="";
  task tick;@(negedge clk);endtask
  task aw(input int len=0);b.d_awlen=len;b.d_awvalid=1;b.d_awready=1;tick();b.d_awvalid=0;endtask
  task w(input bit last=1);b.d_wvalid=1;b.d_wready=1;b.d_wlast=last;tick();b.d_wvalid=0;endtask
  task ar(input int len=0);b.d_arlen=len;b.d_arvalid=1;b.d_arready=1;tick();b.d_arvalid=0;endtask
  task ca; b.c_awvalid=1;b.c_awready=1;tick();b.c_awvalid=0;endtask
  task cw; b.c_wvalid=1;b.c_wready=1;tick();b.c_wvalid=0;endtask
  initial begin
    `include "dma_zero_pins.svh"
    if(!$value$plusargs("SCENARIO=%s",scenario))$fatal(1,"Missing SVA scenario");
    void'($value$plusargs("EXPECT_SVA=%s",expected));
    b.d_awsize=3;b.d_arsize=3;b.d_awburst=1;b.d_arburst=1;b.d_wstrb=255;b.d_rlast=1;
    repeat(3)tick();b.reset_n=1;tick();
    case(scenario)
      "aw_hold":begin b.d_awvalid=1;tick();b.d_awaddr=8;tick();end
      "w_hold":begin b.d_wvalid=1;tick();b.d_wstrb=1;tick();end
      "ar_hold":begin b.d_arvalid=1;tick();b.d_araddr=8;tick();end
      "b_hold":begin aw();w();b.d_bvalid=1;tick();b.d_bresp=2;tick();end
      "r_hold":begin ar();b.d_rvalid=1;tick();b.d_rdata=1;tick();end
      "b_before":begin b.d_bvalid=1;tick();tick();end
      "b_aw_only":begin aw();b.d_bvalid=1;tick();tick();end
      "b_w_only":begin w();b.d_bvalid=1;tick();tick();end
      "b_same_w":begin aw();b.d_bvalid=1;w();end
      "b_same_aw":begin w();b.d_bvalid=1;aw();end
      "b_same_both":begin b.d_bvalid=1;b.d_awvalid=1;b.d_awready=1;w();end
      "r_before":begin b.d_rvalid=1;tick();tick();end
      "r_same_ar":begin b.d_rvalid=1;ar();end
      "aw_attr":begin b.d_awsize=2;aw();end
      "ar_attr":begin b.d_arburst=0;ar();end
      "w_last":begin aw(1);w();end
      "w_last_same_aw":begin b.d_awvalid=1;b.d_awready=1;b.d_awlen=1;w();end
      "w_last_early_count":begin w(0);w(1);aw(0);end
      "w_last_early_missing":begin w(0);aw(0);end
      "r_last":begin ar(1);b.d_rvalid=1;b.d_rready=1;tick();end
      "rid":begin ar();b.d_rvalid=1;b.d_rid=1;tick();end
      "bid":begin aw();w();b.d_bvalid=1;b.d_bid=1;tick();end
      "c_aw_hold":begin b.c_awvalid=1;tick();b.c_awaddr=4;tick();end
      "c_w_hold":begin b.c_wvalid=1;tick();b.c_wdata=1;tick();end
      "c_ar_hold":begin b.c_arvalid=1;tick();b.c_araddr=4;tick();end
      "c_b_hold":begin ca();cw();b.c_bvalid=1;tick();b.c_bresp=2;tick();end
      "c_r_hold":begin b.c_arvalid=1;b.c_arready=1;tick();b.c_arvalid=0;b.c_rvalid=1;tick();b.c_rdata=1;tick();end
      "c_b_before":begin b.c_bvalid=1;tick();end
      "c_r_before":begin b.c_rvalid=1;tick();end
      "legal":begin
        // All sixteen W beats precede AW; B can be held under backpressure.
        for(int i=0;i<16;i++)w(i==15);
        aw(15);b.d_bvalid=1;repeat(3)tick();b.d_bready=1;tick();b.d_bvalid=0;
        ar(1);b.d_rvalid=1;b.d_rlast=0;repeat(2)tick();b.d_rready=1;tick();b.d_rlast=1;tick();b.d_rvalid=0;
        // Cancel a partial write with reset, then issue a fresh transaction.
        aw();b.reset_n=0;tick();b.reset_n=1;tick();w();aw();b.d_bvalid=1;tick();b.d_bvalid=0;
        ca();cw();b.c_bvalid=1;tick();b.c_bready=1;tick();b.c_bvalid=0;
      end
      default:$fatal(1,"Unknown SVA scenario %s",scenario);
    endcase
    // Finish before further driven malformed samples can create extra obligations.
    if(b.sva_count!=(expected==""?0:1))$fatal(1,"SVA detection count %0d",b.sva_count);
    $display("DMA_SVA_CONTROL_PASS name=%s detections=%0d",scenario,b.sva_count);$finish;
  end
  initial begin #100000;$fatal(1,"SVA control watchdog");end
endmodule
