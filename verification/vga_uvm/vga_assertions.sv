`timescale 1ns/1ps
// Expectations come from the public-clock raster and independent framebuffer
// models. Assertions see settled actual pins; reset checking remains enabled.
module vga_assertions(vga_bus bus);
  task automatic detected(input string id);
    bus.assertion_detections++;
    $display("VGA_SVA_DETECTED %s time=%0t",id,$time);
  endtask
  a_hsync: assert property (@(bus.sample_tick) !bus.check_reset |->
    bus.hsync === bus.expected_h) else detected("HSYNC");
  a_vsync: assert property (@(bus.sample_tick) !bus.check_reset |->
    bus.vsync === bus.expected_v) else detected("VSYNC");
  a_active: assert property (@(bus.sample_tick) !bus.check_reset |->
    bus.active_video === bus.expected_active) else detected("ACTIVE");
  a_blank: assert property (@(bus.sample_tick) !bus.check_reset && !bus.expected_active |->
    {bus.red,bus.green,bus.blue} === 12'h000) else detected("BLANK");
  a_rgb: assert property (@(bus.sample_tick) !bus.check_reset && bus.expected_active |->
    {bus.red,bus.green,bus.blue} === bus.expected_rgb) else detected("RGB");
  a_reset: assert property (@(bus.sample_tick) bus.check_reset |->
    {bus.hsync,bus.vsync,bus.active_video,bus.red,bus.green,bus.blue} ===
    {3'b111,bus.expected_rgb}) else detected("RESET");
endmodule
