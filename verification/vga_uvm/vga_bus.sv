`timescale 1ns/1ps
interface vga_bus;
  logic clk=0;
  // Packed controls permit an atomic, race-free stimulus update.
  logic [22:0] controls={1'b1,22'd0}, intended={1'b1,22'd0};
  wire reset=controls[22],sram_we=controls[21];
  wire [12:0] sram_addr=controls[20:8];
  wire [7:0] sram_data_in=controls[7:0];
  wire hsync,vsync,active_video;
  wire [3:0] red,green,blue;
  bit sample_tick=0,capture=0;
  bit check_reset=0,expected_h=1,expected_v=1,expected_active=1;
  logic [11:0] expected_rgb=12'he00;
  int assertion_detections=0;
  always #5 clk=~clk; // 10 ns testbench input period, not a board clock claim.
endinterface
