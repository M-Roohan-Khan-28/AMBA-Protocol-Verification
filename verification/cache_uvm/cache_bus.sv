`timescale 1ns/1ps
interface cache_bus;
  // A single packed update avoids driver ordering races among public inputs.
  // No observation tick, request handshake or DUT internal state is exposed.
  logic [16:0] pins=0;
  wire clk=pins[16],reset=pins[15],write=pins[14],way_select=pins[13];
  wire [1:0] index=pins[12:11];
  wire [2:0] tag=pins[10:8];
  wire [7:0] data_in=pins[7:0];
  logic hit;logic [7:0] data_out;
  int sva_count=0;
endinterface
