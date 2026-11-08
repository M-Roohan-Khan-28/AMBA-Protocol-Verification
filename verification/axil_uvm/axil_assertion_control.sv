`timescale 1ns/1ps
// Each negative is a separate simulation, with exactly one named detection.
module axil_assertion_control;
  bit clk=0;always #5 clk=~clk;
  axil_bus b(clk);axil_assertions assertions(b);
  int scenario;
  task automatic accept_aw();
    b.awvalid=1;b.awready=1;
    @(negedge clk);b.awvalid=0;
  endtask
  task automatic accept_w();
    b.wvalid=1;b.wready=1;
    @(negedge clk);b.wvalid=0;
  endtask
  task automatic accept_ar();
    b.arvalid=1;b.arready=1;
    @(negedge clk);b.arvalid=0;
  endtask
  task automatic legal_write(int order);
    b.awready=1;b.wready=1;
    if(order==0)begin accept_aw();repeat(2)@(negedge clk);accept_w();end
    if(order==1)begin accept_w();repeat(2)@(negedge clk);accept_aw();end
    if(order==2)begin b.awvalid=1;b.wvalid=1;@(negedge clk);b.awvalid=0;b.wvalid=0;end
    b.bvalid=1;b.bready=0;
    repeat(3)@(negedge clk);
    b.bready=1;@(negedge clk);b.bvalid=0;b.bready=0;
  endtask
  initial begin
    b.awaddr=0;b.awprot=0;b.awvalid=0;b.awready=0;b.wdata=0;b.wstrb=0;b.wvalid=0;b.wready=0;
    b.bvalid=0;b.bready=0;b.bresp=0;b.araddr=0;b.arprot=0;b.arvalid=0;b.arready=0;
    b.rvalid=0;b.rready=0;b.rdata=0;b.rresp=0;
    if(!$value$plusargs("CASE=%d",scenario))$fatal(1,"Missing CASE");
    repeat(2)@(negedge clk);b.reset_n=1;@(negedge clk);
    case(scenario)
      0:begin b.awvalid=1;b.awready=0;@(negedge clk);b.awaddr=4;end
      1:begin b.wvalid=1;b.wready=0;@(negedge clk);b.wstrb=1;end
      2:begin b.arvalid=1;b.arready=0;@(negedge clk);b.araddr=4;end
      3:begin accept_aw();accept_w();b.bvalid=1;b.bready=0;@(negedge clk);b.bresp=2;end
      4:begin accept_ar();b.rvalid=1;b.rready=0;@(negedge clk);b.rdata=1;end
      5:begin b.bvalid=1;b.bready=0;end // no accepted AW or W, READY low
      6:begin accept_aw();b.bvalid=1;b.bready=0;end // W absent
      7:begin accept_w();b.bvalid=1;b.bready=0;end // AW absent
      8:begin accept_aw();b.wvalid=1;b.wready=1;b.bvalid=1;b.bready=1;end // same-edge W cannot authorize B
      9:begin b.rvalid=1;b.rready=0;end // no accepted AR, READY low
      10:begin b.arvalid=1;b.arready=1;b.rvalid=1;b.rready=1;end // same-edge AR cannot authorize R
      11:begin accept_w();b.awvalid=1;b.awready=1;b.bvalid=1;b.bready=1;end // same-edge AW cannot authorize B
      12:begin b.awvalid=1;b.awready=1;b.wvalid=1;b.wready=1;b.bvalid=1;b.bready=1;end // both missing before edge
      13:begin
        legal_write(0);legal_write(1);legal_write(2);
        accept_ar();b.rvalid=1;b.rready=0;b.rdata=32'h28a6beef;
        repeat(3)@(negedge clk);b.rready=1;@(negedge clk);b.rvalid=0;
      end
      default:$fatal(1,"Unknown assertion control");
    endcase
    @(posedge clk);#1;
    if(b.assertion_failures!=(scenario==13?0:1))$fatal(1,"Wrong assertion count %0d",b.assertion_failures);
    $display("AXIL_SVA_CONTROL_PASS case=%0d detections=%0d",scenario,b.assertion_failures);
    $finish;
  end
  initial begin #2000;$fatal(1,"Assertion control timeout");end
endmodule
