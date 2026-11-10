`timescale 1ns/1ps
module vga_sva_control;
  vga_bus bus();
  logic hs=1,vs=1,av=1;
  logic [11:0] rgb=12'ha5a;
  assign bus.hsync=hs;assign bus.vsync=vs;assign bus.active_video=av;
  assign {bus.red,bus.green,bus.blue}=rgb;
  vga_assertions assertion_checker(bus);
  string scenario;int expected;
  task automatic sample;
    #1;bus.sample_tick=~bus.sample_tick;#1;
  endtask
  initial begin
    string run_id;
    if(!$value$plusargs("RUN_ID=%s",run_id))$fatal(1,"RUN_ID_REQUIRED");
    $display("VGA_RUN_ID %s",run_id);
    if(!$value$plusargs("SCENARIO=%s",scenario)) $fatal(1,"SCENARIO_REQUIRED");
    bus.expected_rgb=rgb;
    sample();
    expected=1;
    case(scenario)
      "hsync":hs=0;
      "vsync":vs=0;
      "active":av=0;
      "blank":begin bus.expected_active=0;av=0;bus.expected_rgb=0;rgb=1;end
      "rgb":rgb=12'h123;
      "reset":begin bus.check_reset=1;rgb=0;end
      "legal_reset_write":begin
        expected=0;bus.check_reset=1;bus.controls={1'b1,1'b1,13'd0,8'ha5};
        rgb=12'hb25;bus.expected_rgb=rgb;
      end
      "legal_reset_nonblack":begin expected=0;bus.check_reset=1;end
      "legal_current_write":begin expected=0;rgb=12'hfed;bus.expected_rgb=rgb;end
      "legal_inactive_inputs":begin expected=0;bus.controls={2'b00,13'd8191,8'hff};end
      default:$fatal(1,"UNKNOWN_SCENARIO");
    endcase
    sample();
    if(bus.assertion_detections!=expected) $fatal(1,"VGA_SVA_COUNT expected=%0d actual=%0d",expected,bus.assertion_detections);
    $display("VGA_SVA_CONTROL_PASS name=%s detections=%0d",scenario,bus.assertion_detections);
    $finish;
  end
  initial begin #100; $fatal(1,"VGA_CONTROL_TIMEOUT"); end
endmodule
