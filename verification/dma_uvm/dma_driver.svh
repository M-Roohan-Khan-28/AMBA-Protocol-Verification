class dma_control_driver extends uvm_driver#(dma_command);
  `uvm_component_utils(dma_control_driver)
  dma_config cfg;dma_scoreboard sb;dma_memory_responder responder;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  task idle_pins;
    cfg.vif.c_awvalid=0;cfg.vif.c_wvalid=0;cfg.vif.c_arvalid=0;cfg.vif.c_bready=0;cfg.vif.c_rready=0;
  endtask
  task reset;
    @(negedge cfg.vif.clk);idle_pins();cfg.vif.reset_n=0;
    repeat(4)@(negedge cfg.vif.clk);cfg.vif.reset_n=1;
    repeat(3)@(negedge cfg.vif.clk);
    sb.check_memory(responder);
  endtask
  task write_csr(bit[31:0] address,data,bit[3:0] strobes=15,int response=0,int order=-1);
    bit ad=0,wd=0,bd=0;int cycles=0,ad_delay,wd_delay,b_wait=0;
    if(order<0)order=cfg.scenario.csr_order;
    ad_delay=(order==1)?3:0;wd_delay=(order==0)?3:0;
    while(!bd&&cycles<120)begin
      @(negedge cfg.vif.clk);
      cfg.vif.c_awaddr=address;cfg.vif.c_wdata=data;cfg.vif.c_wstrb=strobes;
      cfg.vif.c_awvalid=!ad&&cycles>=ad_delay;cfg.vif.c_wvalid=!wd&&cycles>=wd_delay;
      cfg.vif.c_bready=ad&&wd&&b_wait>=3;
      @(cfg.vif.sample);
      if(cfg.vif.sample.c_awvalid&&cfg.vif.sample.c_awready)ad=1;
      if(cfg.vif.sample.c_wvalid&&cfg.vif.sample.c_wready)wd=1;
      if(ad&&wd)b_wait++;
      if(cfg.vif.sample.c_bvalid&&cfg.vif.sample.c_bready)begin
        bd=1;if(cfg.vif.sample.c_bresp!==response[1:0])`uvm_fatal("CONTROL_WRITE","Unexpected CSR BRESP")
      end
      cycles++;
    end
    if(!bd)`uvm_fatal("CONTROL_PROGRESS","Control write bound exceeded")
    @(negedge cfg.vif.clk);cfg.vif.c_awvalid=0;cfg.vif.c_wvalid=0;cfg.vif.c_bready=0;
  endtask
  task read_csr(bit[31:0] address,output bit[31:0] data,input int response=0);
    bit ad=0,rd=0;int cycles=0,wait_r=0;
    while(!rd&&cycles<120)begin
      @(negedge cfg.vif.clk);cfg.vif.c_araddr=address;cfg.vif.c_arvalid=!ad;cfg.vif.c_rready=ad&&wait_r>=3;
      @(cfg.vif.sample);
      if(cfg.vif.sample.c_arvalid&&cfg.vif.sample.c_arready)ad=1;
      if(ad)wait_r++;
      if(cfg.vif.sample.c_rvalid&&cfg.vif.sample.c_rready)begin
        rd=1;data=cfg.vif.sample.c_rdata;
        if(cfg.vif.sample.c_rresp!==response[1:0])`uvm_fatal("CONTROL_READ","Unexpected CSR RRESP")
      end
      cycles++;
    end
    if(!rd)`uvm_fatal("CONTROL_PROGRESS","Control read bound exceeded")
    @(negedge cfg.vif.clk);cfg.vif.c_arvalid=0;cfg.vif.c_rready=0;
  endtask
  task program_command(bit[31:0] s,d,n);
    bit[31:0] v;
    write_csr(0,s);write_csr(4,d);write_csr(8,n);
    read_csr(0,v);if(v!=s)`uvm_fatal("CONTROL_READBACK","SRC readback")
    read_csr(4,v);if(v!=d)`uvm_fatal("CONTROL_READBACK","DST readback")
    read_csr(8,v);if(v!=n)`uvm_fatal("CONTROL_READBACK","LEN readback")
    write_csr(12,1);
  endtask
  task wait_terminal(int expected);
    bit[31:0] value;int polls=0;
    do begin read_csr(16,value);polls++;if(polls>=1600)`uvm_fatal("PROGRESS","Programmed command completion watchdog") end while(!value[1]);
    if(value!=(expected?14:10))`uvm_fatal("TERMINAL_STATUS","Status busy/done/error/IRQ bits")
    read_csr(20,value);if(value!=expected)`uvm_fatal("TERMINAL_CODE","Unexpected error code")
    repeat(3)begin
      read_csr(16,value);if(value!=(expected?14:10))`uvm_fatal("STICKY_STATUS","Repeated read changed terminal status")
    end
    // Retain command ownership and watch for unsolicited post-completion activity.
    repeat(10)@(negedge cfg.vif.clk);
    sb.check_memory(responder);
  endtask
  task acknowledge;
    bit[31:0] v;write_csr(12,2);read_csr(16,v);if(v!=0)`uvm_fatal("ACK_STATUS","Acknowledgement did not clear status")
    read_csr(20,v);if(v!=0)`uvm_fatal("ACK_CODE","Acknowledgement did not clear error")
  endtask
  task clean_recovery;
    cfg.scenario.read_error_burst=-1;cfg.scenario.write_error_burst=-1;cfg.scenario.malformed=0;cfg.scenario.reset_kind=0;
    program_command(32'h30000,32'h70000,16);wait_terminal(0);acknowledge();
  endtask
  task check_rejected_state;
    bit[31:0] v;
    // Passive public-pin scoreboard retains independent expected CSR/status/IRQ state.
    // All six reads occur before another write, overwrite, reset or responder release.
    read_csr(0,v);read_csr(4,v);read_csr(8,v);
    read_csr(16,v);read_csr(20,v);read_csr(12,v);
    sb.rejection_checkpoints++;
    $display("DMA_REJECTED_STATE_PASS case=%s checkpoint=%0d",cfg.scenario.label,sb.rejection_checkpoints);
  endtask
  task reject_write(bit[31:0] address,data,bit[3:0] strobes=15);
    write_csr(address,data,strobes,2);check_rejected_state();
  endtask
  task invalid_controls;
    bit[31:0] v;
    for(int i=0;i<16;i++)if(i!=15)reject_write(0,32'hbad00000,i[3:0]);
    reject_write(16,0);reject_write(20,0);reject_write(24,0);
    reject_write(1,0);reject_write(2,0);reject_write(3,0);
    reject_write(12,3);reject_write(12,4);reject_write(12,32'h80000000);
    write_csr(12,0);read_csr(12,v);if(v!=0)`uvm_fatal("CONTROL_READBACK","CONTROL read must be zero")
    read_csr(1,v,2);read_csr(24,v,2);read_csr(32'hfffffff0,v,2);
  endtask
  task busy_controls;
    bit[31:0] v;
    read_csr(16,v);if(v!=1)`uvm_fatal("BUSY_STATUS","Expected busy while responder paused")
    reject_write(0,32'hdead0000);reject_write(4,32'hdead1000);reject_write(8,8);
    reject_write(12,1);reject_write(12,2);reject_write(12,0);
    cfg.freeze_data=0;
  endtask
  task cancel_partial_control(int kind);bit[31:0] v;
    @(negedge cfg.vif.clk);
    if(kind==4)begin cfg.vif.c_awaddr=0;cfg.vif.c_awvalid=1;end
    else begin cfg.vif.c_wdata=32'hdeadbeef;cfg.vif.c_wstrb=15;cfg.vif.c_wvalid=1;end
    @(cfg.vif.sample);
    if(kind==4&&!cfg.vif.sample.c_awready||kind==5&&!cfg.vif.sample.c_wready)`uvm_fatal("CONTROL_READY","Partial channel not accepted")
    reset();read_csr(0,v);if(v!=0)`uvm_fatal("RESET_CONTROL","Canceled write changed register")
  endtask
  task run_phase(uvm_phase phase);dma_command item;int watchdog;
    forever begin
      seq_item_port.get_next_item(item);
      @(negedge cfg.vif.clk);cfg.scenario=item;cfg.epoch++;cfg.read_beats=0;cfg.write_commits=0;cfg.b_accepts=0;cfg.freeze_data=0;
      sb.begin_case(item.label);$display("DMA_CASE_START name=%s time=%0t",item.label,$time);
      reset();
      if(item.reset_kind>=4)cancel_partial_control(item.reset_kind);
      if(item.csr_tests==1||item.csr_tests==3)begin
        write_csr(0,32'h23400);write_csr(4,32'h89000);write_csr(8,64);
        invalid_controls();
      end
      if(item.csr_tests==2)cfg.freeze_data=1;
      program_command(item.src,item.dst,item.length);
      if(item.csr_tests==2)busy_controls();
      if(item.reset_kind>=1&&item.reset_kind<=3)begin
        watchdog=0;
        while((item.reset_kind==1&&cfg.read_beats<2)||(item.reset_kind==2&&cfg.b_accepts<1)||(item.reset_kind==3&&cfg.write_commits<1))begin
          @(negedge cfg.vif.clk);watchdog++;if(watchdog>2000)`uvm_fatal("PROGRESS","Reset trigger watchdog")
        end
        reset();clean_recovery();
      end else begin
        wait_terminal(item.expected_error);
        if(item.chain)begin program_command(32'h30000,32'h70000,16);wait_terminal(0);end
        if(item.csr_tests==1||item.csr_tests==3)invalid_controls();
        acknowledge();
        if(item.expected_error!=0)begin if(item.malformed!=0)reset();clean_recovery();end
      end
      repeat(10)@(negedge cfg.vif.clk);
      sb.finish_case(responder);seq_item_port.item_done();
    end
  endtask
endclass
