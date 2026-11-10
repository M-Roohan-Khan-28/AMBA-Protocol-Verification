`timescale 1ns/1ps
module vga_uvm_top;
  import uvm_pkg::*;
  import vga_uvm_pkg::*;
  vga_bus bus();
  vga_controller_sram dut(.clk(bus.clk),.reset(bus.reset),.sram_we(bus.sram_we),
    .sram_addr(bus.sram_addr),.sram_data_in(bus.sram_data_in),.hsync(bus.hsync),
    .vsync(bus.vsync),.active_video(bus.active_video),.red(bus.red),.green(bus.green),.blue(bus.blue));
  vga_assertions assertions(bus);
  initial begin
    string run_id;
    if(!$value$plusargs("RUN_ID=%s",run_id))$fatal(1,"RUN_ID_REQUIRED");
    $display("VGA_RUN_ID %s",run_id);
    $dumpfile("pins.vcd");
    $dumpvars(0,bus.clk,bus.reset,bus.sram_we,bus.sram_addr,bus.sram_data_in,
      bus.hsync,bus.vsync,bus.active_video,bus.red,bus.green,bus.blue);
    $dumpoff;
    uvm_config_db#(virtual vga_bus)::set(null,"*","vif",bus);
    run_test("vga_test");
  end
  always @(bus.capture) if(bus.capture) $dumpon; else $dumpoff;
  initial begin #300000000; $fatal(1,"VGA_PROGRESS_TIMEOUT"); end
endmodule
