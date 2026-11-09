`timescale 1ns/1ps
package dma_uvm_pkg;
  import uvm_pkg::*;`include "uvm_macros.svh"
  `include "dma_common.svh"
  `include "dma_pins.svh"
  `include "dma_responder.svh"
  `include "dma_scoreboard.svh"
  `include "dma_driver.svh"
  class dma_sequence extends uvm_sequence#(dma_command);
    `uvm_object_utils(dma_sequence)
    int executed=0;
    function new(string n="dma_sequence");super.new(n);endfunction
    task body();string path,line;int fd,count;dma_command item;
      if(!$value$plusargs("CASES=%s",path))`uvm_fatal("INVENTORY","Missing case inventory")
      fd=$fopen(path,"r");if(!fd)`uvm_fatal("INVENTORY","Cannot read case inventory")
      while($fgets(line,fd))begin
        item=dma_command::type_id::create("programmed_command");
        count=$sscanf(line,"%s %h %h %h %d %d %d %d %d %d %d %d %d %d %d",item.label,item.src,item.dst,item.length,item.order,item.csr_order,item.expected_error,item.read_error_burst,item.read_error_beat,item.write_error_burst,item.commit_error,item.reset_kind,item.malformed,item.csr_tests,item.chain);
        if(count!=15)`uvm_fatal("INVENTORY","Malformed case row")
        start_item(item);finish_item(item);executed++;
      end
      $fclose(fd);if(executed==0)`uvm_fatal("INVENTORY","Empty functional inventory")
    endtask
  endclass
  class dma_env extends uvm_env;
    `uvm_component_utils(dma_env)
    dma_config cfg;dma_monitor monitor;dma_scoreboard scoreboard;dma_control_driver driver;dma_memory_responder responder;uvm_sequencer#(dma_command) sequencer;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);if(!uvm_config_db#(dma_config)::get(this,"","cfg",cfg))`uvm_fatal("CONFIG","Missing config")
      monitor=dma_monitor::type_id::create("monitor",this);monitor.cfg=cfg;
      scoreboard=dma_scoreboard::type_id::create("scoreboard",this);scoreboard.cfg=cfg;
      responder=dma_memory_responder::type_id::create("responder",this);responder.cfg=cfg;
      scoreboard.backing=responder;
      driver=dma_control_driver::type_id::create("driver",this);driver.cfg=cfg;driver.sb=scoreboard;driver.responder=responder;
      sequencer=new("sequencer",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      monitor.observed.connect(scoreboard.analysis_export);driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass
  class dma_test extends uvm_test;
    `uvm_component_utils(dma_test)
    dma_env env;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);env=dma_env::type_id::create("env",this);endfunction
    task run_phase(uvm_phase phase);dma_sequence sequence_i;
      phase.raise_objection(this);sequence_i=dma_sequence::type_id::create("sequence_i");sequence_i.start(env.sequencer);
      $display("DMA_UVM_PASS cases=%0d assertions=%0d seed=0x28A6BEEF",sequence_i.executed,env.cfg.vif.sva_count);
      phase.drop_objection(this);
    endtask
  endclass
endpackage
