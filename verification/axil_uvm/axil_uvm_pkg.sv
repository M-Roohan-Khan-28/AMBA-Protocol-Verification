`timescale 1ns/1ps
package axil_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  localparam bit[31:0] BASE=32'h10000000;
  typedef enum {TRANSFER,RESET,PIPELINE} kind_t;
  class axil_item extends uvm_sequence_item;
    `uvm_object_utils(axil_item)
    kind_t kind=TRANSFER;
    bit wr;
    bit[31:0] addr,data;
    bit[3:0] strb=15;
    int aw_delay=0,w_delay=0,ar_delay=0,b_delay=0,r_delay=0;
    // 1 AW-only; 2 W-only; 3 pending B; 4 pending AR/R; 5 held R.
    int cancel=0;
    function new(string n="axil_item");super.new(n);endfunction
  endclass
  class axil_config extends uvm_object;
    `uvm_object_utils(axil_config)
    virtual axil_bus vif;
    int adapter;
    int aw_delay,w_delay,ar_delay,b_delay,r_delay;
    function new(string n="axil_config");super.new(n);endfunction
  endclass
  class axil_frame extends uvm_sequence_item;
    `uvm_object_utils(axil_frame)
    logic reset_n,awv,awr,wv,wr,bv,br,arv,arr,rv,rr;
    logic[31:0] awa,wd,ara,rd;logic[3:0] ws;logic[1:0] bs,rs;
    logic qv,qr,qw,sv,se;logic[31:0] qa,qd,sd;logic[3:0] qs;
    function new(string n="axil_frame");super.new(n);endfunction
  endclass
  class axil_monitor extends uvm_component;
    `uvm_component_utils(axil_monitor)
    axil_config cfg;
    uvm_analysis_port #(axil_frame) observed;
    function new(string n,uvm_component p);super.new(n,p);observed=new("observed",this);endfunction
    task run_phase(uvm_phase phase);
      axil_frame f;
      forever begin
        @(cfg.vif.sample); f=axil_frame::type_id::create("pins");
        f.reset_n=cfg.vif.sample.reset_n;
        f.awv=cfg.vif.sample.awvalid;f.awr=cfg.vif.sample.awready;f.awa=cfg.vif.sample.awaddr;
        f.wv=cfg.vif.sample.wvalid;f.wr=cfg.vif.sample.wready;f.wd=cfg.vif.sample.wdata;f.ws=cfg.vif.sample.wstrb;
        f.bv=cfg.vif.sample.bvalid;f.br=cfg.vif.sample.bready;f.bs=cfg.vif.sample.bresp;
        f.arv=cfg.vif.sample.arvalid;f.arr=cfg.vif.sample.arready;f.ara=cfg.vif.sample.araddr;
        f.rv=cfg.vif.sample.rvalid;f.rr=cfg.vif.sample.rready;f.rd=cfg.vif.sample.rdata;f.rs=cfg.vif.sample.rresp;
        f.qv=cfg.vif.sample.req_valid;f.qr=cfg.vif.sample.req_ready;f.qw=cfg.vif.sample.req_write;
        f.qa=cfg.vif.sample.req_addr;f.qd=cfg.vif.sample.req_wdata;f.qs=cfg.vif.sample.req_wstrb;
        f.sv=cfg.vif.sample.response_valid;f.se=cfg.vif.sample.response_error;f.sd=cfg.vif.sample.response_data;
        observed.write(f);
      end
    endtask
  endclass
  class axil_scoreboard extends uvm_subscriber #(axil_frame);
    `uvm_component_utils(axil_scoreboard)
    axil_config cfg;
    // Independent byte-addressed model, initially unknown like the SRAM.
    // Reset cancels control, but does NOT clear SRAM or these expected bytes.
    logic[7:0] memory[64];
    bit aw,w,ar,b_seen,r_seen,cpu,done,in_reset;
    bit cpu_wr,done_error;logic[31:0] cpu_addr,cpu_data,done_data;
    logic[3:0] cpu_strb,strobe;
    logic[31:0] address,wdata,read_address;
    int cycle,aw_cycle,w_cycle;
    int comparisons=0,writes=0,reads=0,requests=0,completions=0,resets=0,discarded=0;
    int address_first=0,data_first=0,simultaneous=0,invalid_writes=0,invalid_reads=0;
    int aw_stalls=0,w_stalls=0,ar_stalls=0,b_stalls=0,r_stalls=0;
    int strobe_hits[16],written[16],read_hits[16];
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function bit legal(logic[31:0] a);
      return !$isunknown(a) && a>=BASE && a<BASE+64 && (a%4)==0;
    endfunction
    function logic[31:0] expected_read(logic[31:0] a);
      logic[31:0] value;int offset;
      if(!legal(a)) return 0;
      offset=int'(a-BASE);
      for(int lane=0;lane<4;lane++) value[lane*8+:8]=memory[offset+lane];
      return value;
    endfunction
    function void write(axil_frame t);
      axil_frame f;
      bit bad;logic[31:0] value;int offset;
      f=t;
      cycle++;
      if(!f.reset_n) begin
        if(!in_reset) begin resets++;if(aw||w||ar||cpu||done)discarded++;end
        in_reset=1;aw=0;w=0;ar=0;b_seen=0;r_seen=0;cpu=0;done=0;return;
      end
      in_reset=0;
      if(f.awv&&!f.awr)aw_stalls++;if(f.wv&&!f.wr)w_stalls++;if(f.arv&&!f.arr)ar_stalls++;
      if(f.bv&&!f.br)b_stalls++;if(f.rv&&!f.rr)r_stalls++;
      // Completion must refer to a bus response accepted on a PRIOR edge.
      if(cfg.adapter!=0 && f.sv) begin
        if(!cpu||!done) `uvm_fatal("CPU_ELIGIBILITY","Unsolicited/duplicate or same-edge CPU completion")
        comparisons++;
        if(f.se!==done_error) `uvm_fatal("CPU_ERROR","CPU response error mismatch")
        if(!cpu_wr) begin comparisons++;if(f.sd!==done_data) `uvm_fatal("CPU_DATA","CPU read data mismatch") end
        completions++;cpu=0;done=0;
      end
      // Dependencies are checked before this frame's AW/W/AR acceptances.
      if(f.bv) begin
        if(!aw||!w) `uvm_fatal("B_DEPENDENCY","BVALID lacks prior AW and W, regardless of BREADY")
        bad=!legal(address);comparisons++;
        if(f.bs!==(bad?2'b10:2'b00)) `uvm_fatal("B_RESPONSE","Incorrect BRESP")
        if(!b_seen) begin
          b_seen=1;strobe_hits[strobe]++;
          if(bad)invalid_writes++;
          else begin
            offset=int'(address-BASE);written[offset/4]++;
            for(int lane=0;lane<4;lane++)if(strobe[lane])memory[offset+lane]=wdata[lane*8+:8];
          end
          if(aw_cycle<w_cycle)address_first++;else if(w_cycle<aw_cycle)data_first++;else simultaneous++;
        end
        if(f.br)begin writes++;aw=0;w=0;b_seen=0;done=(cfg.adapter!=0);done_error=bad;end
      end
      if(f.rv) begin
        if(!ar) `uvm_fatal("R_DEPENDENCY","RVALID lacks prior AR, regardless of RREADY")
        bad=!legal(read_address);value=expected_read(read_address);comparisons+=2;
        if(f.rs!==(bad?2'b10:2'b00)) `uvm_fatal("R_RESPONSE","Incorrect RRESP")
        if(f.rd!==value) `uvm_fatal("ORACLE_DATA",$sformatf("addr=%h expected=%h observed=%h",read_address,value,f.rd))
        if(!r_seen)begin r_seen=1;if(bad)invalid_reads++;else read_hits[int'(read_address-BASE)/4]++;end
        if(f.rr)begin reads++;ar=0;r_seen=0;done=(cfg.adapter!=0);done_error=bad;done_data=value;end
      end
      if(f.awv&&f.awr) begin
        if(aw) `uvm_fatal("AW_DUPLICATE","Unexpected second outstanding AW")
        if(cfg.adapter!=0)begin
          comparisons++;
          if(!cpu||!cpu_wr||f.awa!==cpu_addr) `uvm_fatal("REQUEST_ADDRESS","AW does not match accepted CPU request")
        end
        aw=1;address=f.awa;aw_cycle=cycle;
      end
      if(f.wv&&f.wr) begin
        if(w) `uvm_fatal("W_DUPLICATE","Unexpected second outstanding W")
        if(cfg.adapter!=0)begin
          comparisons+=2;
          if(!cpu||!cpu_wr||f.wd!==cpu_data||f.ws!==cpu_strb) `uvm_fatal("REQUEST_WRITE","W does not match accepted CPU request")
        end
        w=1;wdata=f.wd;strobe=f.ws;w_cycle=cycle;
      end
      if(f.arv&&f.arr) begin
        if(ar) `uvm_fatal("AR_DUPLICATE","Unexpected second outstanding AR")
        if(cfg.adapter!=0)begin
          comparisons++;
          if(!cpu||cpu_wr||f.ara!==cpu_addr) `uvm_fatal("REQUEST_ADDRESS","AR does not match accepted CPU request")
        end
        ar=1;read_address=f.ara;
      end
      if(cfg.adapter!=0&&f.qv&&f.qr)begin
        if(cpu) `uvm_fatal("CPU_DUPLICATE","More than one outstanding CPU request")
        cpu=1;cpu_wr=f.qw;cpu_addr=f.qa;cpu_data=f.qd;cpu_strb=f.qs;requests++;
      end
    endfunction
    function void check_phase(uvm_phase phase);
      if(aw||w||ar||cpu||(cfg.adapter!=0&&done)) `uvm_fatal("DRAIN","Outstanding transaction at test end")
      if(resets<4||!invalid_writes||!invalid_reads) `uvm_fatal("REQUIREMENT","Missing reset/error scenario")
      foreach(strobe_hits[i])if(!strobe_hits[i]) `uvm_fatal("REQUIREMENT","Missing write-strobe mask")
      foreach(written[i])if(!written[i]||!read_hits[i]) `uvm_fatal("REQUIREMENT","Missing initialized word/readback")
      if(cfg.adapter<2 && (!address_first||!data_first||!simultaneous)) `uvm_fatal("REQUIREMENT","Missing AW/W ordering")
      if(cfg.adapter==0&&(!b_stalls||!r_stalls||!aw_stalls||!w_stalls)) `uvm_fatal("REQUIREMENT","Missing slave backpressure")
      if(cfg.adapter==1&&(!aw_stalls||!w_stalls||!ar_stalls)) `uvm_fatal("REQUIREMENT","Missing independent responder stalls")
    endfunction
    function void report_phase(uvm_phase phase);
      int fd;
      fd=$fopen("requirements.json","w");if(!fd) `uvm_fatal("REPORT","Cannot export counters")
      $fdisplay(fd,"{\"kind\":\"procedural_requirement_hits_NOT_functional_coverage\",\"address_first\":%0d,\"data_first\":%0d,\"simultaneous\":%0d,\"aw_stall_cycles\":%0d,\"w_stall_cycles\":%0d,\"ar_stall_cycles\":%0d,\"b_stall_cycles\":%0d,\"r_stall_cycles\":%0d,\"invalid_writes\":%0d,\"invalid_reads\":%0d,\"strobe_masks_observed\":16,\"resets\":%0d,\"discarded_transactions\":%0d}",address_first,data_first,simultaneous,aw_stalls,w_stalls,ar_stalls,b_stalls,r_stalls,invalid_writes,invalid_reads,resets,discarded);
      $fclose(fd);
    endfunction
  endclass

  // UVM responder has a word model; the passive scoreboard uses byte arithmetic.
  // This component drives only public response/READY pins of the master target.
  class axil_responder extends uvm_component;
    `uvm_component_utils(axil_responder)
    axil_config cfg;
    logic[31:0] words[16];
    logic[31:0] address,data,read_address;
    logic[3:0] strobe;
    bit aw,w,ar,bsent,rsent,committed;
    int aw_age,w_age,ar_age,b_age,r_age;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function bit bad(logic[31:0] a);return a[1:0]!=0||a<32'h10000000||a>32'h1000003c;endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(cfg.vif.sample);
        if(!cfg.vif.sample.reset_n)begin
          aw=0;w=0;ar=0;bsent=0;rsent=0;committed=0;
          aw_age=0;w_age=0;ar_age=0;b_age=0;r_age=0;
        end else begin
          if(cfg.vif.sample.awvalid&&!aw)aw_age++;
          if(cfg.vif.sample.wvalid&&!w)w_age++;
          if(cfg.vif.sample.arvalid&&!ar)ar_age++;
          if(cfg.vif.sample.awvalid&&cfg.vif.sample.awready)begin aw=1;address=cfg.vif.sample.awaddr;end
          if(cfg.vif.sample.wvalid&&cfg.vif.sample.wready)begin w=1;data=cfg.vif.sample.wdata;strobe=cfg.vif.sample.wstrb;end
          if(cfg.vif.sample.arvalid&&cfg.vif.sample.arready)begin ar=1;read_address=cfg.vif.sample.araddr;end
          if(aw&&w)b_age++;
          if(ar)r_age++;
          if(cfg.vif.sample.bvalid&&!committed)begin
            if(!bad(address)) for(int lane=0;lane<4;lane++)if(strobe[lane])words[address[5:2]][lane*8+:8]=data[lane*8+:8];
            committed=1;
          end
          if(cfg.vif.sample.bvalid&&cfg.vif.sample.bready)begin
            aw=0;w=0;bsent=0;committed=0;aw_age=0;w_age=0;b_age=0;
          end
          if(cfg.vif.sample.rvalid&&cfg.vif.sample.rready)begin ar=0;rsent=0;ar_age=0;r_age=0;end
        end
        @(negedge cfg.vif.clk);
        if(!cfg.vif.reset_n)begin
          cfg.vif.awready=0;cfg.vif.wready=0;cfg.vif.arready=0;cfg.vif.bvalid=0;cfg.vif.rvalid=0;
          cfg.vif.bresp=0;cfg.vif.rresp=0;cfg.vif.rdata=0;
        end else begin
          cfg.vif.awready=!aw&&aw_age>cfg.aw_delay;
          cfg.vif.wready=!w&&w_age>cfg.w_delay;
          cfg.vif.arready=!ar&&ar_age>cfg.ar_delay;
          if(aw&&w&&b_age>cfg.b_delay)bsent=1;
          if(ar&&r_age>cfg.r_delay&&!$test$plusargs("FAULT_DROP_RESPONSE"))rsent=1;
          cfg.vif.bvalid=bsent;cfg.vif.bresp=bad(address)?2:0;
          cfg.vif.rvalid=rsent;cfg.vif.rresp=bad(read_address)?2:0;
          cfg.vif.rdata=bad(read_address)?0:words[read_address[5:2]];
        end
      end
    endtask
  endclass

  class axil_driver extends uvm_driver #(axil_item);
    `uvm_component_utils(axil_driver)
    axil_config cfg;
    int completed=0,cancelled=0;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    task reset_bus();
      #2;cfg.vif.reset_n=0;
      if(cfg.adapter==0)begin cfg.vif.awvalid=0;cfg.vif.wvalid=0;cfg.vif.arvalid=0;cfg.vif.bready=0;cfg.vif.rready=0;end
      else cfg.vif.req_valid=0;
      repeat(3)@(negedge cfg.vif.clk);
      cfg.vif.reset_n=1;
      @(negedge cfg.vif.clk);
    endtask
    task slave_transfer(axil_item t);
      bit aa,ww,ar,seen;int age;
      aa=0;ww=0;ar=0;seen=0;age=0;
      cfg.vif.awaddr=t.addr;cfg.vif.wdata=t.data;cfg.vif.wstrb=t.strb;cfg.vif.araddr=t.addr;
      cfg.vif.awvalid=t.wr&&t.aw_delay==0;cfg.vif.wvalid=t.wr&&t.w_delay==0;
      cfg.vif.arvalid=!t.wr&&t.ar_delay==0;cfg.vif.bready=0;cfg.vif.rready=0;
      for(int n=0;n<80;n++)begin
        @(cfg.vif.sample);
        if(cfg.vif.sample.awvalid&&cfg.vif.sample.awready)aa=1;
        if(cfg.vif.sample.wvalid&&cfg.vif.sample.wready)ww=1;
        if(cfg.vif.sample.arvalid&&cfg.vif.sample.arready)ar=1;
        if((t.cancel==1&&aa&&!ww)||(t.cancel==2&&ww&&!aa)||
           (t.cancel==3&&cfg.vif.sample.bvalid)||(t.cancel==4&&ar&&!cfg.vif.sample.rvalid)||
           (t.cancel==5&&cfg.vif.sample.rvalid)) begin reset_bus();cancelled++;return;end
        if((t.wr&&cfg.vif.sample.bvalid)||(!t.wr&&cfg.vif.sample.rvalid))begin seen=1;age++;end
        if((t.wr&&cfg.vif.sample.bvalid&&cfg.vif.sample.bready)||
           (!t.wr&&cfg.vif.sample.rvalid&&cfg.vif.sample.rready))begin
          completed++;@(negedge cfg.vif.clk);cfg.vif.bready=0;cfg.vif.rready=0;return;
        end
        @(negedge cfg.vif.clk);
        cfg.vif.awvalid=t.wr&&!aa&&(n+1>=t.aw_delay);
        cfg.vif.wvalid=t.wr&&!ww&&(n+1>=t.w_delay);
        cfg.vif.arvalid=!t.wr&&!ar&&(n+1>=t.ar_delay);
        cfg.vif.bready=t.wr&&seen&&age>t.b_delay;
        cfg.vif.rready=!t.wr&&seen&&age>t.r_delay;
      end
      `uvm_fatal("PROGRESS","Slave transaction exceeded 80 sampled cycles")
    endtask
    task slave_pipeline(axil_item t);
      bit aa,ww,first_done;int holds;
      cfg.vif.awaddr=t.addr;cfg.vif.wdata=t.data;cfg.vif.wstrb=15;
      cfg.vif.awvalid=1;cfg.vif.wvalid=1;cfg.vif.bready=0;
      aa=0;ww=0;first_done=0;holds=0;
      // First write accepted; queue a second request behind its held response.
      for(int n=0;n<80;n++)begin
        @(cfg.vif.sample);
        if(cfg.vif.sample.awvalid&&cfg.vif.sample.awready)aa=1;
        if(cfg.vif.sample.wvalid&&cfg.vif.sample.wready)ww=1;
        @(negedge cfg.vif.clk);
        if(aa&&ww)break;
        if(n==79) `uvm_fatal("PROGRESS","Pipeline first request timed out")
      end
      cfg.vif.awaddr=t.addr+4;cfg.vif.wdata=~t.data;
      aa=0;ww=0;
      for(int n=0;n<80;n++)begin
        @(cfg.vif.sample);
        if(cfg.vif.sample.bvalid&&!first_done)holds++;
        if(cfg.vif.sample.awvalid&&cfg.vif.sample.awready)aa=1;
        if(cfg.vif.sample.wvalid&&cfg.vif.sample.wready)ww=1;
        if(cfg.vif.sample.bvalid&&cfg.vif.sample.bready)begin
          completed++;
          if(first_done)begin @(negedge cfg.vif.clk);cfg.vif.bready=0;return;end
          first_done=1;
        end
        @(negedge cfg.vif.clk);
        cfg.vif.awvalid=!aa;cfg.vif.wvalid=!ww;cfg.vif.bready=holds>3;
      end
      `uvm_fatal("PROGRESS","Pipeline response bound exceeded")
    endtask
    task master_request(axil_item t);
      bit accepted,aa,ww,ar;
      accepted=0;aa=0;ww=0;ar=0;
      cfg.aw_delay=t.aw_delay;cfg.w_delay=t.w_delay;cfg.ar_delay=t.ar_delay;
      cfg.b_delay=t.b_delay;cfg.r_delay=t.r_delay;
      cfg.vif.req_valid=1;cfg.vif.req_write=t.wr;cfg.vif.req_addr=t.addr;cfg.vif.req_wdata=t.data;cfg.vif.req_wstrb=t.strb;
      for(int n=0;n<80;n++)begin
        @(cfg.vif.sample);
        if(cfg.vif.sample.req_valid&&cfg.vif.sample.req_ready)accepted=1;
        if(cfg.vif.sample.awvalid&&cfg.vif.sample.awready)aa=1;
        if(cfg.vif.sample.wvalid&&cfg.vif.sample.wready)ww=1;
        if(cfg.vif.sample.arvalid&&cfg.vif.sample.arready)ar=1;
        if((t.cancel==1&&aa&&!ww)||(t.cancel==2&&ww&&!aa)||
           (t.cancel==3&&aa&&ww&&!cfg.vif.sample.bvalid)||
           (t.cancel==4&&ar&&!cfg.vif.sample.rvalid))begin reset_bus();cancelled++;return;end
        if(cfg.vif.sample.response_valid)begin
          if(!accepted) `uvm_fatal("REQUEST","Completion before request acceptance")
          completed++;@(negedge cfg.vif.clk);cfg.vif.req_valid=0;return;
        end
        @(negedge cfg.vif.clk);if(accepted)cfg.vif.req_valid=0;
      end
      `uvm_fatal("PROGRESS","Master/integration transaction exceeded 80 sampled cycles")
    endtask
    task run_phase(uvm_phase phase);
      axil_item t;
      @(negedge cfg.vif.clk);
      forever begin
        seq_item_port.get_next_item(t);
        if(t.kind==RESET)reset_bus();
        else if(t.kind==PIPELINE)slave_pipeline(t);
        else if(cfg.adapter==0)slave_transfer(t);
        else master_request(t);
        seq_item_port.item_done();
      end
    endtask
  endclass

  class axil_sequence extends uvm_sequence #(axil_item);
    `uvm_object_utils(axil_sequence)
    axil_config cfg;
    int completed=0,cancelled=0,serial=0;
    function new(string n="axil_sequence");super.new(n);endfunction
    task issue(bit wr,bit[31:0] addr,bit[31:0] data=0,bit[3:0] strb=15,int cancel=0);
      axil_item t=axil_item::type_id::create("transfer");
      start_item(t);t.wr=wr;t.addr=addr;t.data=data;t.strb=strb;t.cancel=cancel;
      case(serial%3)
        0:begin t.aw_delay=0;t.w_delay=4;end
        1:begin t.aw_delay=4;t.w_delay=0;end
        2:begin t.aw_delay=1;t.w_delay=1;end
      endcase
      t.ar_delay=serial%4;t.b_delay=serial%4;t.r_delay=(serial+1)%4;
      if(cancel==1)begin t.aw_delay=0;t.w_delay=12;end
      if(cancel==2)begin t.aw_delay=12;t.w_delay=0;end
      if(cancel==3)t.b_delay=12;
      if(cancel==4||cancel==5)t.r_delay=12;
      finish_item(t);serial++;
      if(cancel)cancelled++;else completed++;
    endtask
    task reset();
      axil_item t=axil_item::type_id::create("reset");start_item(t);t.kind=RESET;finish_item(t);
    endtask
    task read_all();for(int i=0;i<16;i++)issue(0,BASE+4*i);endtask
    task body();
      axil_item t;bit[31:0] d;
      reset();
      // Initialize every word before readback: SRAM is not initialized/reset.
      for(int i=0;i<16;i++)issue(1,BASE+4*i,32'h28a6beef^(32'h9e3779b9*(i+1)));
      read_all();
      // All 16 byte masks at both region boundaries and internal addresses.
      for(int mask=0;mask<16;mask++)begin
        for(int j=0;j<3;j++)begin
          int word_index;word_index=j==0?0:j==1?15:mask;
          d=32'hd3c5a791^(32'h10204081*(mask+1+j));
          issue(1,BASE+word_index*4,d,4'(mask));issue(0,BASE+word_index*4);
        end
      end
      // Misalignment, below/above region, high-address aliases and wrap edge.
      foreach_invalid();
      if(cfg.adapter==0)begin
        t=axil_item::type_id::create("pipeline");start_item(t);t.kind=PIPELINE;t.addr=BASE;t.data=32'ha55a6996;finish_item(t);completed+=2;
        read_all();
      end
      // Retention and no partial-write commit, with reset crossing clock edges.
      if(cfg.adapter<2)begin
        issue(1,BASE,32'hbad00001,15,1);read_all();
        issue(1,BASE+4,32'hbad00002,15,2);read_all();
      end
      issue(1,BASE+8,32'hbad00003,15,3);read_all();
      issue(0,BASE+12,0,15,4);read_all();
      if(cfg.adapter==0)begin issue(0,BASE+16,0,15,5);read_all();end
      reset();read_all();
    endtask
    task foreach_invalid();
      bit[31:0] a;
      for(int j=0;j<8;j++)begin
        case(j)
          0:a=BASE-4;1:a=BASE+64;2:a=BASE+1;3:a=BASE+2;4:a=BASE+3;
          5:a=BASE+32'h10000;6:a=32'hfffffffc;7:a=0;
        endcase
        issue(1,a,32'hffffffff);issue(0,a);
      end
      read_all();
    endtask
  endclass
  class axil_env extends uvm_env;
    `uvm_component_utils(axil_env)
    axil_config cfg;uvm_sequencer #(axil_item) seqr;
    axil_driver driver;axil_monitor monitor;axil_scoreboard scoreboard;axil_responder responder;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(axil_config)::get(this,"","cfg",cfg)) `uvm_fatal("CFG","Missing configuration")
      seqr=new("seqr",this);driver=axil_driver::type_id::create("driver",this);driver.cfg=cfg;
      monitor=axil_monitor::type_id::create("monitor",this);monitor.cfg=cfg;
      scoreboard=axil_scoreboard::type_id::create("scoreboard",this);scoreboard.cfg=cfg;
      if(cfg.adapter==1)begin responder=axil_responder::type_id::create("responder",this);responder.cfg=cfg;end
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(seqr.seq_item_export);monitor.observed.connect(scoreboard.analysis_export);
    endfunction
  endclass
  class axil_test extends uvm_test;
    `uvm_component_utils(axil_test)
    axil_env env;int expected,aborts;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);env=axil_env::type_id::create("env",this);endfunction
    task run_phase(uvm_phase phase);
      axil_sequence seq=axil_sequence::type_id::create("sequence");
      phase.raise_objection(this);seq.cfg=env.cfg;seq.start(env.seqr);expected=seq.completed;aborts=seq.cancelled;
      repeat(4)@(negedge env.cfg.vif.clk);phase.drop_objection(this);
    endtask
    function void check_phase(uvm_phase phase);
      if(env.driver.completed!=expected||env.driver.cancelled!=aborts||env.cfg.vif.assertion_failures!=0)
        `uvm_fatal("EXACT_ONCE","Driver/sequence or assertion count mismatch")
      if(env.cfg.adapter==0)begin
        if(env.scoreboard.writes+env.scoreboard.reads!=expected) `uvm_fatal("EXACT_ONCE","Bus completions mismatch")
      end else begin
        if(env.scoreboard.completions!=expected||env.scoreboard.requests!=expected+aborts)
          `uvm_fatal("EXACT_ONCE","CPU acceptance/completion mismatch")
      end
    endfunction
    function void report_phase(uvm_phase phase);
      uvm_report_server server=uvm_report_server::get_server();
      if(server.get_severity_count(UVM_ERROR)||server.get_severity_count(UVM_FATAL)) `uvm_fatal("SUMMARY","UVM errors")
      $display("AXIL_UVM_PASS adapter=%0d completed=%0d writes=%0d reads=%0d comparisons=%0d resets=%0d cancelled=%0d assertions=0",
        env.cfg.adapter,env.driver.completed,env.scoreboard.writes,env.scoreboard.reads,env.scoreboard.comparisons,env.scoreboard.resets,env.driver.cancelled);
    endfunction
  endclass
endpackage
