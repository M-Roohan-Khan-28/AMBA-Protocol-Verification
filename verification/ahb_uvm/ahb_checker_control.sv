`timescale 1ns/1ps
package ahb_checker_pkg;
  import uvm_pkg::*;import ahb_uvm_pkg::*;`include "uvm_macros.svh"
  class ahb_checker_test extends uvm_test;
    `uvm_component_utils(ahb_checker_test)
    ahb_scoreboard sb;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);sb=ahb_scoreboard::type_id::create("sb",this);endfunction
    function void intent(int id,int addr,bit wr,bit[31:0] data);
      ahb_item t=new;t.offer_id=id;t.reqaddr=addr;t.reqwrite=wr;t.reqsize=2;t.reqdata=data;sb.write_intent(t);
    endfunction
    function void pins(bit sel,bit wr,int addr,bit[31:0] data=0,bit[31:0] rdata=0,bit reset=1);
      ahb_sample s=new;s.reset_n=reset;s.sel=sel;s.wr=wr;s.addr=addr;s.trans=sel?2:0;s.size=2;s.data=data;s.rdata=rdata;s.ready=1;s.readyout=1;s.resp=0;sb.write_sample(s);
    endfunction
    task run_phase(uvm_phase phase);
      string scenario;ahb_item t=new;phase.raise_objection(this);
      if(!$value$plusargs("SCENARIO=%s",scenario))`uvm_fatal("CONTROL","Missing scenario")
      $display("AHB_CHECKER_START name=%s",scenario);
      t.event_kind=1;t.case_name=scenario;sb.write_intent(t);pins(0,0,0,0,0,0);
      intent(1,0,1,32'h13579bdf);
      if(scenario=="omitted")begin sb.check_end();end
      else if(scenario=="alias")pins(1,1,4);
      else begin
        pins(1,1,0,32'hdeadbeef);
        if(scenario=="pairing")pins(0,0,48,32'h2468acfe);
        else if(scenario=="reset")begin
          pins(0,0,0,0,0,0);intent(2,0,0,0);pins(1,0,0);pins(0,1,44,32'haabbccdd,0);
        end else begin
          intent(2,0,0,0);pins(1,0,0,32'h13579bdf);
          pins(0,1,48,32'h98765432,32'h13579bdf);
          if(scenario=="duplicate")pins(1,1,0,32'h13579bdf);
        end
      end
      sb.check_end();$display("AHB_CHECKER_PASS name=%s",scenario);phase.drop_objection(this);
    endtask
  endclass
endpackage
module ahb_checker_control;
  import uvm_pkg::*;import ahb_checker_pkg::*;
  // Elaboration anchor for virtual-interface types in the reusable package.
  // This unit control feeds samples directly; it does not instantiate a DUT.
  logic clk=0;ahb_bus unused_interface(clk);
  initial run_test("ahb_checker_test");
  initial begin #10000;$fatal(1,"CHECKER_TIMEOUT");end
endmodule
