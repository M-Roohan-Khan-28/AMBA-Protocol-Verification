`timescale 1ns/1ps
module probe_uvm;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  class feature_smoke extends uvm_test;
    `uvm_component_utils(feature_smoke)
    function new(string name="feature_smoke", uvm_component parent=null);
      super.new(name,parent);
    endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);
      #1;
      phase.drop_objection(this);
    endtask
    function void report_phase(uvm_phase phase);
      uvm_report_server server;
      super.report_phase(phase);
      server=uvm_report_server::get_server();
      if (server.get_severity_count(UVM_ERROR)!=0 ||
          server.get_severity_count(UVM_FATAL)!=0)
        $fatal(1,"UVM probe has errors");
      $display("FEATURE_PASS_uvm");
    endfunction
  endclass
  initial run_test("feature_smoke");
  initial begin #10000; $fatal(1,"UVM probe watchdog"); end
endmodule
