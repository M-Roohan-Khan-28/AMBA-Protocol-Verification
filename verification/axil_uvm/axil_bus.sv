`timescale 1ns/1ps
// Public AXI and CPU request pins only. Sampling precedes the DUT's NBA updates.
interface axil_bus(input logic clk);
  logic reset_n=0;
  logic [31:0] awaddr,wdata,araddr,rdata;
  logic [2:0] awprot,arprot;
  logic [3:0] wstrb;
  logic [1:0] bresp,rresp;
  logic awvalid,awready,wvalid,wready,bvalid,bready;
  logic arvalid,arready,rvalid,rready;
  logic req_valid,req_write,req_ready,response_valid,response_error;
  logic [31:0] req_addr,req_wdata,response_data;
  logic [3:0] req_wstrb;
  int assertion_failures=0;
  clocking sample @(posedge clk);
    default input #1step;
    input reset_n,awaddr,awprot,awvalid,awready,wdata,wstrb,wvalid,wready;
    input bresp,bvalid,bready,araddr,arprot,arvalid,arready,rdata,rresp,rvalid,rready;
    input req_valid,req_write,req_ready,req_addr,req_wdata,req_wstrb;
    input response_valid,response_error,response_data;
  endclocking
endinterface
