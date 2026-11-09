`timescale 1ns/1ps
package ahb_uvm_pkg;
  import uvm_pkg::*;`include "uvm_macros.svh"
  `uvm_analysis_imp_decl(_intent)
  `uvm_analysis_imp_decl(_sample)
  class ahb_item extends uvm_sequence_item;
    `uvm_object_utils(ahb_item)
    string case_name;int event_kind=0,sel,trans,wr,size,addr,ext,reset_n,offer_id,reqaddr,reqwrite,reqsize,cancel;
    bit [31:0] data,reqdata;
    function new(string n="ahb_item");super.new(n);endfunction
  endclass
  class ahb_sample extends uvm_sequence_item;
    `uvm_object_utils(ahb_sample)
    logic reset_n,sel,wr,ready,readyout,resp;logic[7:0] addr;logic[1:0] trans;logic[2:0] size;logic[31:0] data,rdata;
    function new(string n="ahb_sample");super.new(n);endfunction
  endclass
  class ahb_request;
    int id,addr,wr,size;bit[31:0] data;
    function bit invalid();return addr>60||addr%4!=0||size!=2;endfunction
  endclass
  class ahb_scoreboard extends uvm_component;
    `uvm_component_utils(ahb_scoreboard)
    uvm_analysis_imp_intent #(ahb_item,ahb_scoreboard) intended;
    uvm_analysis_imp_sample #(ahb_sample,ahb_scoreboard) observed;
    ahb_request offered_q[$],pending;bit seen[int];bit[31:0] mem[16];
    int offered,accepted,success,errors,writes,reads,withdrawn,reset_accepted,reset_offered,wait_edges,pipeline_edges,resets,comparisons,cycles,cases;
    bit in_reset=0,active=0;string case_name;
    function new(string n,uvm_component p);super.new(n,p);intended=new("intended",this);observed=new("observed",this);foreach(mem[i])mem[i]=0;endfunction
    function void check_end();
      if(pending!=null||offered_q.size()!=0||offered!=accepted+withdrawn+reset_offered||accepted!=success+errors+reset_accepted)
        `uvm_fatal("REQUEST_ACCOUNT",$sformatf("offered=%0d accepted=%0d retired=%0d withdrawn=%0d reset=%0d/%0d pending=%0d queued=%0d",offered,accepted,success+errors,withdrawn,reset_accepted,reset_offered,pending!=null,offered_q.size()))
    endfunction
    function void write_intent(ahb_item t);
      ahb_request r;int f;
      if(t.event_kind==1)begin
        if(active)`uvm_fatal("CASE_STATE","Nested case")
        check_end();active=1;case_name=t.case_name;offered=0;accepted=0;success=0;errors=0;writes=0;reads=0;withdrawn=0;reset_accepted=0;reset_offered=0;wait_edges=0;pipeline_edges=0;resets=0;comparisons=0;cycles=0;seen.delete();in_reset=0;
        $display("AHB_CASE_START name=%s time=%0t",case_name,$time);return;
      end
      if(t.event_kind==2)begin
        check_end();active=0;cases++;
        f=$fopen({"case-",case_name,".json"},"w");if(!f)`uvm_fatal("RESULT_FILE","Cannot open result")
        $fdisplay(f,"{\"name\":\"%s\",\"offered\":%0d,\"accepted\":%0d,\"success\":%0d,\"errors\":%0d,\"writes\":%0d,\"reads\":%0d,\"withdrawn\":%0d,\"reset_accepted\":%0d,\"reset_offered\":%0d,\"wait_edges\":%0d,\"pipeline_edges\":%0d,\"resets\":%0d,\"comparisons\":%0d,\"cycles\":%0d}",case_name,offered,accepted,success,errors,writes,reads,withdrawn,reset_accepted,reset_offered,wait_edges,pipeline_edges,resets,comparisons,cycles);$fclose(f);
        $display("AHB_CASE_PASS name=%s accepted=%0d retired=%0d reset=%0d comparisons=%0d",case_name,accepted,success+errors,reset_accepted,comparisons);return;
      end
      if(t.offer_id)begin
        if(seen.exists(t.offer_id))`uvm_fatal("INTENT_ID","Repeated intended ID")
        r=new;r.id=t.offer_id;r.addr=t.reqaddr;r.wr=t.reqwrite;r.size=t.reqsize;r.data=t.reqdata;
        offered_q.push_back(r);seen[r.id]=1;offered++;
        $display("AHB_INTENT id=%0d addr=%02h write=%0d size=%0d data=%08h",r.id,r.addr,r.wr,r.size,r.data);
      end
      if(t.cancel)begin
        if(offered_q.size()!=1||offered_q[0].id!=t.cancel)`uvm_fatal("CANCEL_OWNER","Cancel must name the unaccepted speculative request")
        r=offered_q.pop_front();withdrawn++;$display("AHB_WITHDRAW id=%0d",r.id);
      end
    endfunction
    function void write_sample(ahb_sample s);
      ahb_request next;bit had_pending;
      if(!active)return;
      cycles++;
      if(!s.reset_n)begin
        if(!in_reset)begin resets++;reset_accepted+=(pending!=null);reset_offered+=offered_q.size();end
        pending=null;offered_q.delete();foreach(mem[i])mem[i]=0;in_reset=1;return;
      end
      in_reset=0;
      if($isunknown({s.ready,s.readyout,s.resp,s.sel,s.trans,s.wr,s.addr,s.size}))`uvm_fatal("UNKNOWN_PINS","Unknown control")
      if(!s.ready)wait_edges++;
      // Stronger endpoint zero-output contract, not a general AHB data rule.
      if(pending==null||pending.wr||pending.invalid())begin
        comparisons++;if(s.rdata!==0)`uvm_fatal("EP_ZERO_DATA","Non-read endpoint output was nonzero")
      end
      had_pending=pending!=null;
      if(s.ready)begin
        if(pending!=null)begin
          comparisons++;
          if(s.resp!==pending.invalid())`uvm_fatal("RESPONSE_KIND",$sformatf("id=%0d expected_error=%0d observed=%b",pending.id,pending.invalid(),s.resp))
          if(pending.wr)begin
            comparisons++;if(s.data!==pending.data)`uvm_fatal("WRITE_PAIR",$sformatf("id=%0d saved_addr=%02h expected=%08h observed=%08h",pending.id,pending.addr,pending.data,s.data))
          end
          if(pending.invalid())errors++;
          else begin
            success++;
            if(pending.wr)begin mem[pending.addr/4]=pending.data;writes++;end
            else begin
              reads++;comparisons++;
              if(s.rdata!==mem[pending.addr/4])`uvm_fatal("READ_DATA",$sformatf("id=%0d saved_addr=%02h expected=%08h observed=%08h",pending.id,pending.addr,mem[pending.addr/4],s.rdata))
            end
          end
          $display("AHB_RETIRE id=%0d error=%0d",pending.id,pending.invalid());pending=null;
        end else if(s.resp)`uvm_fatal("RESPONSE_OWNER","Response without accepted address")
        // Prior data retires before new address is accepted on this same edge.
        if(s.sel&&s.trans[1])begin
          if(!offered_q.size())`uvm_fatal("UNSOLICITED_ADDRESS","No intended request owns selected address")
          next=offered_q.pop_front();comparisons+=3;
          if(s.addr!==8'(next.addr)||s.wr!==1'(next.wr)||s.size!==3'(next.size))
            `uvm_fatal("ADDRESS_INTENT",$sformatf("id=%0d expected=%02h/%0d/%0d observed=%02h/%0d/%0d",next.id,next.addr,next.wr,next.size,s.addr,s.wr,s.size))
          pending=next;accepted++;if(had_pending)pipeline_edges++;
          $display("AHB_ACCEPT id=%0d addr=%02h write=%0d",next.id,s.addr,s.wr);
        end
      end
    endfunction
  endclass
  class ahb_driver extends uvm_driver #(ahb_item);
    `uvm_component_utils(ahb_driver)
    virtual ahb_bus vif;uvm_analysis_port #(ahb_item) intended;string fault="";
    function new(string n,uvm_component p);super.new(n,p);intended=new("intended",this);endfunction
    task run_phase(uvm_phase phase);
      ahb_item t;void'($value$plusargs("FAULT=%s",fault));
      forever begin
        seq_item_port.get_next_item(t);
        if(t.event_kind!=0)begin intended.write(t);seq_item_port.item_done();continue;end
        @(negedge vif.clk);intended.write(t);
        vif.reset_n=t.reset_n;vif.sel=t.sel;vif.trans=t.trans;vif.write=t.wr;vif.size=t.size;vif.addr=t.addr;
        if(fault=="address_alias")vif.addr=t.addr&8'hfb;
        vif.wdata=t.data;vif.ext_ready=t.ext;
        @(vif.sample);#2;
        seq_item_port.item_done();
      end
    endtask
  endclass
  class ahb_monitor extends uvm_component;
    `uvm_component_utils(ahb_monitor)
    virtual ahb_bus vif;uvm_analysis_port #(ahb_sample) observed;string fault="";bit dropped=0;
    function new(string n,uvm_component p);super.new(n,p);observed=new("observed",this);endfunction
    task run_phase(uvm_phase phase);
      ahb_sample s;void'($value$plusargs("FAULT=%s",fault));
      forever begin
        @(vif.sample);s=ahb_sample::type_id::create("pins");
        s.reset_n=vif.sample.reset_n;s.sel=vif.sample.sel;s.trans=vif.sample.trans;s.wr=vif.sample.write;s.addr=vif.sample.addr;s.size=vif.sample.size;
        s.data=vif.sample.wdata;s.rdata=vif.sample.rdata;s.ready=vif.sample.ready;s.readyout=vif.sample.readyout;s.resp=vif.sample.resp;
        if(fault=="omit_observation"&&!dropped&&s.reset_n&&s.ready&&s.sel&&s.trans[1])begin
          s.sel=0;dropped=1;$display("AHB_FAULT_OMITTED_ADDRESS_OBSERVATION");
        end
        observed.write(s);
      end
    endtask
  endclass
  class ahb_sequence extends uvm_sequence #(ahb_item);
    `uvm_object_utils(ahb_sequence)
    function new(string n="ahb_sequence");super.new(n);endfunction
    task body();
      int f,count;string path,line;ahb_item t;
      if(!$value$plusargs("PROGRAM=%s",path))`uvm_fatal("PROGRAM","Missing schedule")
      f=$fopen(path,"r");if(!f)`uvm_fatal("PROGRAM","Cannot open schedule")
      while($fgets(line,f))begin
        t=ahb_item::type_id::create("named_cycle");
        count=$sscanf(line,"%s %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d",t.case_name,t.event_kind,t.sel,t.trans,t.wr,t.size,t.addr,t.data,t.ext,t.reset_n,t.offer_id,t.reqaddr,t.reqwrite,t.reqsize,t.reqdata,t.cancel);
        if(count!=16)`uvm_fatal("PROGRAM","Malformed cycle")
        start_item(t);finish_item(t);
      end
      $fclose(f);
    endtask
  endclass
  class ahb_test extends uvm_test;
    `uvm_component_utils(ahb_test)
    ahb_driver driver;ahb_monitor monitor;ahb_scoreboard scoreboard;uvm_sequencer #(ahb_item) sequencer;virtual ahb_bus vif;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual ahb_bus)::get(this,"","vif",vif))`uvm_fatal("VIF","Missing interface")
      driver=ahb_driver::type_id::create("driver",this);monitor=ahb_monitor::type_id::create("monitor",this);scoreboard=ahb_scoreboard::type_id::create("scoreboard",this);sequencer=new("sequencer",this);
      driver.vif=vif;monitor.vif=vif;
    endfunction
    function void connect_phase(uvm_phase phase);driver.seq_item_port.connect(sequencer.seq_item_export);driver.intended.connect(scoreboard.intended);monitor.observed.connect(scoreboard.observed);endfunction
    task run_phase(uvm_phase phase);
      ahb_sequence seq;phase.raise_objection(this);seq=ahb_sequence::type_id::create("deterministic");seq.start(sequencer);#1;
      if(vif.sva_count)`uvm_fatal("SVA_COUNT","Unexpected assertion detection")
      $display("AHB_UVM_PASS cases=%0d assertions=0 seed=0x28A6BEEF",scoreboard.cases);phase.drop_objection(this);
    endtask
  endclass
endpackage
