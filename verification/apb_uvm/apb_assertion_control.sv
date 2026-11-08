`timescale 1ns/1ps
// One reset-isolated malformed trace per simulation. No DUT is attached.
module apb_assertion_control;
  bit clk=0;
  always #5 clk=~clk;
  apb_bus b(clk);
  apb_assertions check_apb(b);
  int scenario;
  initial begin
    b.ready=0; b.error=0; b.rdata=0;
    if(!$value$plusargs("CASE=%d",scenario)) $fatal(1,"Missing assertion control case");
    repeat(2) @(negedge clk);
    b.reset_n=1;
    @(negedge clk);
    case(scenario)
      0: begin // malformed setup -> changed payload at ACCESS
        b.select=1; b.addr=0;
        @(negedge clk); b.enable=1; b.addr=4; b.ready=1;
      end
      1: begin // payload changes during a wait
        b.select=1;
        @(negedge clk); b.enable=1;
        @(negedge clk); b.addr=4;
      end
      2: begin b.select=1; b.enable=1; b.ready=1; end
      3: begin b.select=0; b.enable=1; end
      4: begin b.error=1; end
      5: begin // legal setup, two wait cycles, then response
        b.select=1;
        @(negedge clk); b.enable=1;
        repeat(2) @(negedge clk);
        b.ready=1;
      end
      default:$fatal(1,"Bad control case");
    endcase
    @(posedge clk); #1;
    if(b.assertion_failures != (scenario==5 ? 0 : 1))
      $fatal(1,"Expected %0d assertion detections, saw %0d",scenario==5?0:1,b.assertion_failures);
    $display("APB_SVA_CONTROL_PASS case=%0d detections=%0d",scenario,b.assertion_failures);
    $finish;
  end
  initial begin #1000; $fatal(1,"Assertion control timeout"); end
endmodule
