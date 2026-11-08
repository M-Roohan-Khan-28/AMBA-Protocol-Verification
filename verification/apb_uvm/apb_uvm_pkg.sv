`timescale 1ns/1ps
package apb_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  typedef enum {TRANSFER, RESET, ABORT_SETUP, ABORT_WAIT} kind_t;
  class apb_item extends uvm_sequence_item;
    `uvm_object_utils(apb_item)
    kind_t kind=TRANSFER;
    bit write;
    bit [7:0] addr;
    bit [31:0] data;
    logic [31:0] rdata;
    logic error;
    int waits;
    function new(string name="apb_item"); super.new(name); endfunction
  endclass

  class apb_config extends uvm_object;
    `uvm_object_utils(apb_config)
    virtual apb_bus vif;
    int adapter;
    function new(string name="apb_config"); super.new(name); endfunction
    function int words(); return adapter==0 ? 64 : 4; endfunction
    function bit invalid(bit[7:0] a);
      case(adapter)
        0: return 0;
        1: return int'(a)>12 || (int'(a)%4)!=0;
        default: return (int'(a)/4)>=3;
      endcase
    endfunction
  endclass

  class apb_driver extends uvm_driver #(apb_item);
    `uvm_component_utils(apb_driver)
    apb_config cfg;
    int submitted=0, completed=0, aborted=0;
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task reset_bus();
      // Reset asserted between edges; no memory request may complete here.
      #2; cfg.vif.reset_n=0; cfg.vif.select=0; cfg.vif.enable=0;
      repeat(2) @(negedge cfg.vif.clk);
      cfg.vif.reset_n=1;
    endtask
    task run_phase(uvm_phase phase);
      apb_item t;
      @(negedge cfg.vif.clk);
      forever begin
        seq_item_port.get_next_item(t);
        if(t.kind==RESET) reset_bus();
        else begin
          cfg.vif.select=1; cfg.vif.enable=0; cfg.vif.write=t.write;
          cfg.vif.addr=t.addr; cfg.vif.wdata=t.data;
          if(t.kind==ABORT_SETUP) begin reset_bus(); aborted++; end
          else begin
            @(negedge cfg.vif.clk); cfg.vif.enable=1;
            if(t.kind==ABORT_WAIT) begin
              @(cfg.vif.sample);
              if(cfg.vif.sample.ready) `uvm_fatal("ABORT","Expected pending wait")
              @(negedge cfg.vif.clk); reset_bus(); aborted++;
            end else begin
              bit accepted;
              accepted=0; submitted++;
              for(int timeout=0; timeout<16; timeout++) begin
                @(cfg.vif.sample);
                if(cfg.vif.sample.ready===1'b1) begin accepted=1; break; end
              end
              if(!accepted) `uvm_fatal("TIMEOUT","APB acceptance bound exceeded")
              completed++;
              @(negedge cfg.vif.clk); cfg.vif.enable=0; cfg.vif.select=0;
            end
          end
        end
        seq_item_port.item_done();
      end
    endtask
  endclass

  class apb_monitor extends uvm_component;
    `uvm_component_utils(apb_monitor)
    apb_config cfg;
    uvm_analysis_port #(apb_item) observed;
    int waits=0;
    bit in_reset=0;
    function new(string n,uvm_component p);
      super.new(n,p); observed=new("observed",this);
    endfunction
    task run_phase(uvm_phase phase);
      apb_item t;
      forever begin
        @(cfg.vif.sample);
        if(!cfg.vif.sample.reset_n) begin
          if(!in_reset) begin
            t=apb_item::type_id::create("reset"); t.kind=RESET; observed.write(t);
          end
          in_reset=1; waits=0;
        end else begin
          in_reset=0;
          if(cfg.vif.sample.select && cfg.vif.sample.enable) begin
            if(cfg.vif.sample.ready===1'b1) begin
              t=apb_item::type_id::create("accepted"); t.kind=TRANSFER;
              t.addr=cfg.vif.sample.addr; t.write=cfg.vif.sample.write;
              t.data=cfg.vif.sample.wdata; t.rdata=cfg.vif.sample.rdata;
              t.error=cfg.vif.sample.error; t.waits=waits;
              observed.write(t); waits=0;
            end else waits++;
          end else waits=0;
        end
      end
    endtask
  endclass

  class apb_scoreboard extends uvm_subscriber #(apb_item);
    `uvm_component_utils(apb_scoreboard)
    apb_config cfg;
    bit[31:0] expected[64];
    int transfers=0, comparisons=0, resets=0, errors=0, reads=0, writes=0;
    function new(string n,uvm_component p); super.new(n,p); endfunction
    function void write(apb_item t);
      bit bad;
      int index;
      if(t.kind==RESET) begin
        foreach(expected[i]) expected[i]=0;
        resets++; return;
      end
      // Independent word-address arithmetic and contract-derived errors.
      // Never inspects DUT memory or relies on driver expected responses.
      index=int'(t.addr)/4; bad=cfg.invalid(t.addr); transfers++; comparisons++;
      if(t.error!==bad) `uvm_fatal("ORACLE_ERROR",$sformatf("addr=%h expected=%b observed=%b",t.addr,bad,t.error))
      if(bad) begin
        errors++;
        if(!t.write) begin
          comparisons++;
          if(t.rdata!==0) `uvm_fatal("ORACLE_ERROR_DATA","Invalid read must return zero")
        end
      end else if(t.write) begin expected[index]=t.data; writes++; end
      else begin
        reads++; comparisons++;
        if(t.rdata!==expected[index])
          `uvm_fatal("ORACLE_DATA",$sformatf("addr=%h expected=%h observed=%h",t.addr,expected[index],t.rdata))
      end
    endfunction
  endclass

  // Requirements trace counters run in every mode. They are NOT simulator
  // functional coverage. The optional covergroup is a separate measured model.
  class apb_coverage extends uvm_subscriber #(apb_item);
    `uvm_component_utils(apb_coverage)
    apb_config cfg;
    int reset_seen=0, read_seen=0, write_seen=0, invalid_read=0, invalid_write=0;
    int alias_seen=0, wait_seen=0, words_read[64], words_written[64];
    int pattern_seen[4];
`ifdef APB_ENABLE_COVERGROUP
    // Separate applicable requirements avoid counting unsupported errors/waits
    // as holes in a zero-wait, no-error RAM's denominator.
    covergroup traffic_cg(int last_word) with function sample(bit wr, int word_index, int pattern);
      option.per_instance=1;
      direction: coverpoint wr { bins read={0}; bins write={1}; }
      word_address: coverpoint word_index { bins words[]={[0:last_word]}; }
      data_class: coverpoint pattern iff(wr) { bins zero={0}; bins ones={1}; bins alternating={2}; bins mixed={3}; }
      direction_word: cross direction,word_address;
    endgroup
    covergroup reset_cg with function sample(bit observed);
      option.per_instance=1;
      reset_event: coverpoint observed { bins reset={1}; }
    endgroup
    covergroup error_cg with function sample(bit wr, int category);
      option.per_instance=1;
      direction: coverpoint wr { bins read={0}; bins write={1}; }
      cause: coverpoint category { bins local_invalid={0}; bins out_of_range={1}; }
      direction_cause: cross direction,cause;
    endgroup
    covergroup alias_cg with function sample(bit[1:0] offset);
      option.per_instance=1;
      byte_offset: coverpoint offset { bins offsets[]={[0:3]}; }
    endgroup
    covergroup wait_cg with function sample(int cycles);
      option.per_instance=1;
      wait_cycles: coverpoint cycles { bins configured_two={2}; }
    endgroup
`endif
    function new(string n,uvm_component p);
      super.new(n,p);
    endfunction
    function void build_phase(uvm_phase phase);
`ifdef APB_ENABLE_COVERGROUP
      traffic_cg=new(cfg.adapter==2 ? 2 : cfg.words()-1);
      reset_cg=new();
      if(cfg.adapter!=0) error_cg=new();
      if(cfg.adapter==0) alias_cg=new();
      if(cfg.adapter==2) wait_cg=new();
`endif
    endfunction
    function void write(apb_item t);
      int index,pattern;
      if(t.kind==RESET) begin
        reset_seen++;
`ifdef APB_ENABLE_COVERGROUP
        reset_cg.sample(1);
`endif
        return;
      end
      index=int'(t.addr)/4;
      if(t.error) begin if(t.write) invalid_write++; else invalid_read++; end
      else begin
        if(t.write) begin write_seen++; words_written[index]++; end
        else begin read_seen++; words_read[index]++; end
        if(t.addr%4) alias_seen++;
      end
      if(t.waits) wait_seen++;
      if(t.write && !t.error) begin
        case(t.data)
          0:pattern_seen[0]++; '1:pattern_seen[1]++;
          32'haaaa5555:pattern_seen[2]++; default:pattern_seen[3]++;
        endcase
      end
`ifdef APB_ENABLE_COVERGROUP
      case(t.data)
        0:pattern=0; '1:pattern=1;32'haaaa5555:pattern=2;default:pattern=3;
      endcase
      if(!t.error) traffic_cg.sample(t.write,index,pattern);
      if(t.error && cfg.adapter!=0) error_cg.sample(t.write,index>=cfg.words()?1:0);
      if(cfg.adapter==0) alias_cg.sample(t.addr[1:0]);
      if(cfg.adapter==2) wait_cg.sample(t.waits);
`endif
    endfunction
    function void check_phase(uvm_phase phase);
      int usable;
      usable=cfg.adapter==2 ? 3 : cfg.words();
      if(reset_seen<3 || read_seen==0 || write_seen==0)
        `uvm_fatal("REQ","Missing reset/read/write requirement")
      for(int i=0;i<usable;i++)
        if(words_read[i]==0 || words_written[i]==0) `uvm_fatal("REQ","Missing word address")
      foreach(pattern_seen[i]) if(!pattern_seen[i]) `uvm_fatal("REQ","Missing data class")
      if(cfg.adapter!=0 && (!invalid_read || !invalid_write)) `uvm_fatal("REQ","Missing errors")
      if(cfg.adapter==0 && !alias_seen) `uvm_fatal("REQ","Missing aliases")
      if(cfg.adapter==2 && !wait_seen) `uvm_fatal("REQ","Missing waits")
    endfunction
    function void report_phase(uvm_phase phase);
      int fd;
      fd=$fopen("requirements.json","w");
      if(!fd) `uvm_fatal("REPORT","Cannot export requirement counters")
      $fdisplay(fd,"{\"kind\":\"procedural_requirement_hits_NOT_functional_coverage\",\"adapter\":%0d,\"resets\":%0d,\"reads\":%0d,\"writes\":%0d,\"invalid_reads\":%0d,\"invalid_writes\":%0d,\"aliases\":%0d,\"waited_transfers\":%0d}",cfg.adapter,reset_seen,read_seen,write_seen,invalid_read,invalid_write,alias_seen,wait_seen);
      $fclose(fd);
    endfunction
  endclass

  class apb_deterministic_sequence extends uvm_sequence #(apb_item);
    `uvm_object_utils(apb_deterministic_sequence)
    apb_config cfg;
    int count=0;
    function new(string n="apb_deterministic_sequence"); super.new(n); endfunction
    task issue(kind_t kind,bit wr=0,bit[7:0] addr=0,bit[31:0] data=0);
      apb_item t=apb_item::type_id::create("item");
      start_item(t); t.kind=kind;t.write=wr;t.addr=addr;t.data=data;finish_item(t);
      if(kind==TRANSFER) count++;
    endtask
    task body();
      int usable;
      bit[31:0] d;
      usable=cfg.adapter==2 ? 3 : cfg.words();
      issue(RESET);
      for(int i=0;i<cfg.words();i++) issue(TRANSFER,0,8'(i*4));
      for(int p=0;p<4;p++) begin
        for(int i=0;i<usable;i++) begin
          case(p)
            0:d=0;1:d='1;2:d=32'haaaa5555;default:d=32'h28a6beef^(32'h9e3779b9*(i+1));
          endcase
          issue(TRANSFER,1,8'(i*4),d);
        end
        for(int i=usable-1;i>=0;i--) issue(TRANSFER,0,8'(i*4));
      end
      // All 256 byte addresses: legal aliases versus invalid read/write, then
      // read all valid words to detect invalid-write side effects independently.
      for(int a=0;a<256;a++) begin
        issue(TRANSFER,1,8'(a),32'h62000000^32'(a*65537));
        issue(TRANSFER,0,8'(a));
      end
      for(int i=0;i<usable;i++) issue(TRANSFER,0,8'(i*4));
      issue(ABORT_SETUP,1,0,32'hdeadbeef);
      for(int i=0;i<cfg.words();i++) issue(TRANSFER,0,8'(i*4));
      if(cfg.adapter==2) begin
        issue(ABORT_WAIT,1,0,32'hbad0cafe);
        for(int i=0;i<usable;i++) issue(TRANSFER,0,8'(i*4));
      end
      issue(RESET);
      for(int i=0;i<cfg.words();i++) issue(TRANSFER,0,8'(i*4));
    endtask
  endclass

  class apb_env extends uvm_env;
    `uvm_component_utils(apb_env)
    apb_config cfg;
    uvm_sequencer #(apb_item) seqr;
    apb_driver driver;
    apb_monitor monitor;
    apb_scoreboard scoreboard;
    apb_coverage coverage;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(apb_config)::get(this,"","cfg",cfg)) `uvm_fatal("CFG","Missing config")
      seqr=new("seqr",this);
      driver=apb_driver::type_id::create("driver",this);driver.cfg=cfg;
      monitor=apb_monitor::type_id::create("monitor",this);monitor.cfg=cfg;
      scoreboard=apb_scoreboard::type_id::create("scoreboard",this);scoreboard.cfg=cfg;
      coverage=apb_coverage::type_id::create("coverage",this);coverage.cfg=cfg;
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(seqr.seq_item_export);
      monitor.observed.connect(scoreboard.analysis_export);
      monitor.observed.connect(coverage.analysis_export);
    endfunction
  endclass

  class apb_deterministic_test extends uvm_test;
    `uvm_component_utils(apb_deterministic_test)
    apb_env env;
    int expected_count;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);env=apb_env::type_id::create("env",this);endfunction
    task run_phase(uvm_phase phase);
      apb_deterministic_sequence seq=apb_deterministic_sequence::type_id::create("seq");
      phase.raise_objection(this);
      seq.cfg=env.cfg; seq.start(env.seqr);expected_count=seq.count;
      repeat(3) @(negedge env.cfg.vif.clk);
      phase.drop_objection(this);
    endtask
    function void check_phase(uvm_phase phase);
      if(env.scoreboard.transfers!=expected_count || env.driver.completed!=expected_count ||
         env.driver.submitted!=expected_count || env.cfg.vif.assertion_failures!=0)
        `uvm_fatal("EXACT_ONCE","Submission/acceptance/completion mismatch or assertion failure")
    endfunction
    function void report_phase(uvm_phase phase);
      uvm_report_server server=uvm_report_server::get_server();
      if(server.get_severity_count(UVM_ERROR) || server.get_severity_count(UVM_FATAL))
        `uvm_fatal("SUMMARY","Nonzero UVM errors")
      $display("APB_UVM_PASS adapter=%0d transfers=%0d comparisons=%0d resets=%0d aborted=%0d assertions=0",
        env.cfg.adapter,env.scoreboard.transfers,env.scoreboard.comparisons,env.scoreboard.resets,env.driver.aborted);
    endfunction
  endclass
endpackage
