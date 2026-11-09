`timescale 1ns/1ps
interface ahb_bus(input logic clk);
  logic reset_n=0,sel=0,write=0,ext_ready=1;
  logic [7:0] addr=0;
  logic [1:0] trans=0;
  logic [2:0] size=2;
  logic [31:0] wdata=0,rdata;
  logic ready,readyout,resp;
  int sva_count=0;
  clocking sample @(posedge clk);
    default input #1step;
    input reset_n,sel,write,addr,trans,size,wdata,rdata,ready,readyout,resp,ext_ready;
  endclocking
endinterface
