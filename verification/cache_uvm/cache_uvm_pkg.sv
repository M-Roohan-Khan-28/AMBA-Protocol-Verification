`timescale 1ns/1ps
package cache_uvm_pkg;
  import uvm_pkg::*;`include "uvm_macros.svh"
  `uvm_analysis_imp_decl(_intent)
  `uvm_analysis_imp_decl(_sample)
  class cache_item extends uvm_sequence_item;
    `uvm_object_utils(cache_item)
    string case_name;int kind;bit[16:0] pins;
    function new(string n="cache_item");super.new(n);endfunction
  endclass
  class cache_sample extends uvm_sequence_item;
    `uvm_object_utils(cache_sample)
    bit clk,reset,wr,way,rising,reset_edge;bit[1:0] index;bit[2:0] tag;bit[7:0] data;
    logic hit;logic[7:0] result;
    function new(string n="cache_sample");super.new(n);endfunction
  endclass
  class cache_scoreboard extends uvm_component;
    `uvm_component_utils(cache_scoreboard)
    uvm_analysis_imp_intent #(cache_item,cache_scoreboard) intended;
    uvm_analysis_imp_sample #(cache_sample,cache_scoreboard) observed;
    bit valid[2][4];bit[2:0] tags[2][4];bit[7:0] bytes[2][4];
    bit active=0;string name;int cases=0,observations,clocks,writes,blocked_writes,resets,lookups,hits,misses,comparisons;
    function new(string n,uvm_component p);super.new(n,p);intended=new("intended",this);observed=new("observed",this);endfunction
    function void write_intent(cache_item t);
      int f;
      if(t.kind==1)begin
        if(active)`uvm_fatal("CASE_STATE","Nested case")
        active=1;name=t.case_name;observations=0;clocks=0;writes=0;blocked_writes=0;resets=0;lookups=0;hits=0;misses=0;comparisons=0;
        $display("CACHE_CASE_START name=%s time=%0t",name,$time);
      end else if(t.kind==2)begin
        if(!active||name!=t.case_name||observations!=lookups||hits+misses!=lookups||comparisons!=2*observations)`uvm_fatal("ACCOUNTING","Observation mismatch")
        f=$fopen({"case-",name,".json"},"w");if(!f)`uvm_fatal("RESULT_FILE","Cannot write result")
        $fdisplay(f,"{\"name\":\"%s\",\"observations\":%0d,\"clocks\":%0d,\"writes\":%0d,\"blocked_writes\":%0d,\"resets\":%0d,\"lookups\":%0d,\"hits\":%0d,\"misses\":%0d,\"comparisons\":%0d}",name,observations,clocks,writes,blocked_writes,resets,lookups,hits,misses,comparisons);$fclose(f);
        $display("CACHE_CASE_PASS name=%s observations=%0d writes=%0d resets=%0d comparisons=%0d time=%0t",name,observations,writes,resets,comparisons,$time);active=0;cases++;
      end
    endfunction
    function void write_sample(cache_sample s);
      bit eh;bit[7:0] ed;
      if(!active)return;
      observations++;clocks+=s.rising;resets+=s.reset_edge;
      if(s.reset_edge||(s.rising&&s.reset))begin
        foreach(valid[w,i])begin valid[w][i]=0;tags[w][i]=0;bytes[w][i]=0;end
      end
      if(s.rising&&s.wr)begin
        if(s.reset)blocked_writes++;
        else begin valid[s.way][s.index]=1;tags[s.way][s.index]=s.tag;bytes[s.way][s.index]=s.data;writes++;end
      end
      eh=0;ed=0;
      if(valid[0][s.index]&&tags[0][s.index]==s.tag)begin eh=1;ed=bytes[0][s.index];end
      else if(valid[1][s.index]&&tags[1][s.index]==s.tag)begin eh=1;ed=bytes[1][s.index];end
      lookups++;if(eh)hits++;else misses++;comparisons+=2;
      if(s.hit!==eh)`uvm_fatal("CACHE_HIT",$sformatf("case=%s set=%0d tag=%0d expected=%b observed=%b",name,s.index,s.tag,eh,s.hit))
      if(s.result!==ed)`uvm_fatal("CACHE_DATA",$sformatf("case=%s set=%0d tag=%0d expected=%02h observed=%02h",name,s.index,s.tag,ed,s.result))
    endfunction
  endclass
  class cache_sequence extends uvm_sequence #(cache_item);
    `uvm_object_utils(cache_sequence)
    function new(string n="cache_sequence");super.new(n);endfunction
    task body();
      int f,n;string path,line;cache_item t;
      if(!$value$plusargs("PROGRAM=%s",path))`uvm_fatal("PROGRAM","Missing schedule")
      f=$fopen(path,"r");if(!f)`uvm_fatal("PROGRAM","Cannot open schedule")
      while($fgets(line,f))begin
        t=cache_item::type_id::create("deterministic_item");n=$sscanf(line,"%s %d %h",t.case_name,t.kind,t.pins);
        if(n!=3)`uvm_fatal("PROGRAM","Malformed schedule")
        start_item(t);finish_item(t);
      end
      $fclose(f);
    endtask
  endclass
  class cache_driver extends uvm_driver #(cache_item);
    `uvm_component_utils(cache_driver)
    virtual cache_bus vif;uvm_analysis_port #(cache_item) intended;
    function new(string n,uvm_component p);super.new(n,p);intended=new("intended",this);endfunction
    task run_phase(uvm_phase phase);
      cache_item t;
      forever begin
        seq_item_port.get_next_item(t);
        if(t.kind!=0)intended.write(t);
        else begin #5;vif.pins=t.pins;#5;end
        seq_item_port.item_done();
      end
    endtask
  endclass
  class cache_monitor extends uvm_component;
    `uvm_component_utils(cache_monitor)
    virtual cache_bus vif;uvm_analysis_port #(cache_sample) observed;bit old_clk=0,old_reset=0;
    function new(string n,uvm_component p);super.new(n,p);observed=new("observed",this);endfunction
    task run_phase(uvm_phase phase);
      cache_sample s;
      forever begin
        @(vif.pins);#0;s=cache_sample::type_id::create("public_pins");
        s.clk=vif.clk;s.reset=vif.reset;s.wr=vif.write;s.way=vif.way_select;s.index=vif.index;s.tag=vif.tag;s.data=vif.data_in;
        s.rising=!old_clk&&s.clk;s.reset_edge=!old_reset&&s.reset;old_clk=s.clk;old_reset=s.reset;
        #1;s.hit=vif.hit;s.result=vif.data_out;observed.write(s);
      end
    endtask
  endclass
  class cache_env extends uvm_env;
    `uvm_component_utils(cache_env)
    cache_driver driver;cache_monitor monitor;cache_scoreboard scoreboard;uvm_sequencer #(cache_item) sequencer;virtual cache_bus vif;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual cache_bus)::get(this,"","vif",vif))`uvm_fatal("VIF","Missing interface")
      driver=cache_driver::type_id::create("driver",this);monitor=cache_monitor::type_id::create("monitor",this);scoreboard=cache_scoreboard::type_id::create("scoreboard",this);sequencer=new("sequencer",this);driver.vif=vif;monitor.vif=vif;
    endfunction
    function void connect_phase(uvm_phase phase);driver.seq_item_port.connect(sequencer.seq_item_export);driver.intended.connect(scoreboard.intended);monitor.observed.connect(scoreboard.observed);endfunction
  endclass
  class cache_test extends uvm_test;
    `uvm_component_utils(cache_test)
    cache_env env;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);env=cache_env::type_id::create("env",this);endfunction
    task run_phase(uvm_phase phase);
      cache_sequence seq;phase.raise_objection(this);seq=cache_sequence::type_id::create("deterministic");seq.start(env.sequencer);#5;
      if(env.vif.sva_count)`uvm_fatal("SVA_COUNT","Unexpected assertion failure")
      $display("CACHE_UVM_PASS cases=%0d assertions=0 seed=0x28A6BEEF",env.scoreboard.cases);phase.drop_objection(this);
    endtask
  endclass
endpackage
