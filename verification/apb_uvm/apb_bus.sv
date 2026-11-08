`timescale 1ns/1ps
// New verification interface; native DUT interfaces remain in their repositories.
interface apb_bus(input logic clk);
  logic reset_n=0, select=0, enable=0, write=0;
  logic [7:0] addr=0;
  logic [31:0] wdata=0, rdata;
  logic ready, error;
  int assertion_failures=0;
  clocking sample @(posedge clk);
    default input #1step;
    input reset_n, select, enable, write, addr, wdata, rdata, ready, error;
  endclocking
endinterface
