class dma_scoreboard extends uvm_subscriber#(dma_frame);
  `uvm_component_utils(dma_scoreboard)
  dma_config cfg;dma_memory_responder backing;
  byte unsigned memory[addr_t],snapshot[int];bit protected_bytes[addr_t];
  bit ca,cw,cb_seen,cr;bit[31:0] caddr,cdata,crdata;bit[3:0] cstrb;bit[1:0] crresp;
  bit[31:0] src,dst,length;bit active,done,error,in_reset;int code,stage;
  addr_t offset,chunk;int beats,rn,wn;bit aw_seen,write_committed,read_fault;
  int commands,terminals,successes,errors,cancellations,acks,control_rejected,control_cancelled,reads;
  int ars,aws,rbeats,wbeats,bs,commits,comparisons,reset_count;
  int cancelled_ar,cancelled_aw,cancelled_rbeats,cancelled_wbeats,cancelled_b;
  int aw_cycle,w_cycle,cycle,aw_first,w_first,same_edge,all_w_before_aw;
  string label;
  bit[31:0] last_araddr,last_awaddr;bit[7:0] last_arlen,last_awlen,last_wstrb;bit[63:0] last_wdata;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function void require(bit yes,string id,string detail);
    comparisons++;if(!yes)`uvm_fatal(id,$sformatf("case=%s %s",label,detail))
  endfunction
  function byte unsigned mem(addr_t a);return memory.exists(a)?memory[a]:initial_byte(a);endfunction
  function void begin_case(string n);
    label=n;memory.delete();snapshot.delete();protected_bytes.delete();
    commands=0;terminals=0;successes=0;errors=0;cancellations=0;acks=0;control_rejected=0;control_cancelled=0;reads=0;
    ars=0;aws=0;rbeats=0;wbeats=0;bs=0;commits=0;comparisons=0;reset_count=0;
    cancelled_ar=0;cancelled_aw=0;cancelled_rbeats=0;cancelled_wbeats=0;cancelled_b=0;
    aw_first=0;w_first=0;same_edge=0;all_w_before_aw=0;active=0;in_reset=0;
  endfunction
  function void terminal(int e);
    require(active,"ORACLE_OWNERSHIP","terminal without active command");active=0;done=1;error=(e!=0);code=e;
    terminals++;if(e==0)successes++;else errors++;stage=0;
    if(e==0&&(cfg.fault=="duplicate_read"||cfg.fault=="duplicate_write"))begin
      check_memory(backing);$display("DMA_FAULT_BASELINE_MEMORY_OK kind=%s before_duplicate=1",cfg.fault);
    end
  endfunction
  function void plan();addr_t endoff,srcpage,dstpage;
    // Absolute byte limits, not the RTL's remaining-beat combinational logic.
    endoff=offset+128;if(endoff>addr_t'(length))endoff=length;
    srcpage=4096-((addr_t'(src)+offset)%4096);dstpage=4096-((addr_t'(dst)+offset)%4096);
    if(endoff>offset+srcpage)endoff=offset+srcpage;
    if(endoff>offset+dstpage)endoff=offset+dstpage;
    chunk=endoff-offset;beats=int'((chunk+7)/8);rn=0;wn=0;aw_seen=0;write_committed=0;read_fault=0;aw_cycle=-1;w_cycle=-1;
  endfunction
  function void start_command();addr_t se,de,a;bit invalid;
    require(!active,"ORACLE_OWNERSHIP","accepted start reused active command");commands++;
    done=0;error=0;code=0;offset=0;active=1;stage=0;
    se=addr_t'(src)+addr_t'(length);de=addr_t'(dst)+addr_t'(length);
    invalid=length>4096||src%8!=0||dst%8!=0||se>64'h100000000||de>64'h100000000||(addr_t'(src)<de&&addr_t'(dst)<se);
    if(length==0)terminal(0);
    else if(invalid)terminal(1);
    else begin
      for(int i=0;i<int'(length);i++)snapshot[i]=mem(addr_t'(src)+i);
      for(int i=-16;i<int'(length)+16;i++)begin
        if((i>=0||addr_t'(src)>=-i)&&addr_t'(src)+i<64'h100000000)protected_bytes[addr_t'(src)+i]=1;
        if((i>=0||addr_t'(dst)>=-i)&&addr_t'(dst)+i<64'h100000000)protected_bytes[addr_t'(dst)+i]=1;
      end
      protected_bytes[64'h55550000]=1;protected_bytes[0]=1;protected_bytes[64'hffffffff]=1;plan();
    end
  endfunction
  function void csr_response(dma_frame f);bit[1:0] expect_resp;
    if(f.c_bvalid&&!cb_seen)begin
      require(ca&&cw,"CSR_ELIGIBILITY","B before captured control AW/W");expect_resp=0;
      if(cstrb!=15)expect_resp=2;
      else case(caddr)
        0,4,8:if(active)expect_resp=2;else case(caddr)0:src=cdata;4:dst=cdata;8:length=cdata;endcase
        12:if(active||cdata[31:2]!=0||cdata[1:0]==3)expect_resp=2;
           else if(cdata[1])begin done=0;error=0;code=0;acks++;end
           else if(cdata[0])start_command();
        default:expect_resp=2;
      endcase
      require(f.c_bresp===expect_resp,"CSR_RESPONSE","write response or acceptance policy");
      if(expect_resp!=0)control_rejected++;
      cb_seen=1;
    end
    if(f.c_bvalid&&f.c_bready)begin ca=0;cw=0;cb_seen=0;end
    if(f.c_rvalid)begin
      require(cr,"CSR_ELIGIBILITY","R before AR");require(f.c_rdata===crdata&&f.c_rresp===crresp,"CSR_READ","CSR data/status mismatch");
      if(f.c_rready)begin cr=0;reads++;end
    end
    if(f.c_arvalid&&f.c_arready)begin
      require(!cr,"CSR_OWNERSHIP","second outstanding control read");cr=1;crresp=0;
      case(f.c_araddr)
        0:crdata=src;4:crdata=dst;8:crdata=length;12:crdata=0;
        16:crdata={28'd0,done,error,done,active};20:crdata=code;
        default:begin crdata=0;crresp=2;end
      endcase
    end
    if(f.c_awvalid&&f.c_awready)begin require(!ca,"CSR_OWNERSHIP","duplicate control AW");ca=1;caddr=f.c_awaddr;end
    if(f.c_wvalid&&f.c_wready)begin require(!cw,"CSR_OWNERSHIP","duplicate control W");cw=1;cdata=f.c_wdata;cstrb=f.c_wstrb;end
  endfunction
  function void write(dma_frame t);bit[7:0] mask;addr_t a;bit[63:0] expected_word;dma_frame f;
    f=t;
    cycle++;
    if(!f.reset_n)begin
      if(!in_reset)begin
        reset_count++;
        if(active)begin
          cancellations++;cancelled_ar+=(stage==1);cancelled_aw+=aw_seen;cancelled_rbeats+=rn;cancelled_wbeats+=wn;cancelled_b+=write_committed;
        end
        if(ca||cw)control_cancelled++;
      end
      in_reset=1;active=0;done=0;error=0;code=0;stage=0;src=0;dst=0;length=0;ca=0;cw=0;cr=0;cb_seen=0;rn=0;wn=0;aw_seen=0;write_committed=0;return;
    end
    in_reset=0;
    csr_response(f);
    require(f.irq===done,"IRQ_STATUS","IRQ must match sticky terminal state");
    if(f.d_bvalid)require(active&&stage==2&&write_committed,"ORACLE_OWNERSHIP","B without prior owned complete write");
    // Process write channels before read completion: same-edge read/write reuse is not accepted.
    if(f.d_awvalid&&f.d_awready)begin
      if(!active&&cfg.fault=="duplicate_write")begin
        require(f.d_awaddr===last_awaddr&&f.d_awlen===last_awlen&&f.d_wvalid&&f.d_wready&&f.d_wdata===last_wdata&&f.d_wstrb===last_wstrb,"DUPLICATE_CONTROL_SANITY","Duplicate must repeat unchanged accepted write");
        $display("DMA_DUPLICATE_ACCEPTED kind=write bit_identical=1 address=%h data=%h strobes=%h",f.d_awaddr,f.d_wdata,f.d_wstrb);
      end
      require(active&&stage==2&&!aw_seen,"ORACLE_AW_OWNERSHIP","unsolicited/duplicate AW or wrong command phase");
      require({32'd0,f.d_awaddr}==addr_t'(dst)+offset,"ORACLE_AW_ADDRESS","destination/burst progression");
      require(f.d_awid==0&&f.d_awsize==3&&f.d_awburst==1&&f.d_awlen==beats-1,"ORACLE_AW_ATTR","write burst attributes");
      aw_seen=1;aw_cycle=cycle;aws++;if(wn==beats)all_w_before_aw++;
      last_awaddr=f.d_awaddr;last_awlen=f.d_awlen;
    end
    if(f.d_wvalid&&f.d_wready)begin
      require(active&&stage==2&&wn<beats,"ORACLE_W_OWNERSHIP","unsolicited/duplicate W beat");
      if(wn==0)w_cycle=cycle;
      mask=255;if(wn==beats-1&&chunk%8!=0)mask=(1<<(chunk%8))-1;
      require(f.d_wstrb===mask,"ORACLE_WSTRB","tail/active byte mask");
      require(f.d_wlast===(wn==beats-1),"ORACLE_WLAST","write LAST progression");
      for(int i=0;i<8;i++)begin
        a=offset+8*wn+i;
        require(f.d_wdata[8*i+:8]===((a<length)?snapshot[int'(a)]:mem(addr_t'(src)+a)),"ORACLE_WDATA","buffered source byte mismatch");
      end
      wn++;wbeats++;
      last_wdata=f.d_wdata;last_wstrb=f.d_wstrb;
    end
    if(active&&stage==2&&aw_seen&&wn==beats&&!write_committed)begin
      if(aw_cycle<w_cycle)aw_first++;else if(w_cycle<aw_cycle)w_first++;else same_edge++;
      // Explicit responder policy: commit at complete AW+W, even if a later B errors,
      // except the named noncommit-error scenario. No rollback on reset.
      if(!(cfg.scenario.write_error_burst==bs&&!cfg.scenario.commit_error))
        for(int i=0;i<int'(chunk);i++)memory[addr_t'(dst)+offset+i]=snapshot[int'(offset)+i];
      write_committed=1;commits++;
    end
    if(f.d_bvalid&&f.d_bready)begin
      bs++;if(f.d_bresp!=0||f.d_bid!=0)terminal(3);
      else begin offset+=chunk;if(offset==length)terminal(0);else begin stage=0;plan();end end
    end
    if(f.d_rvalid)require(active&&stage==1,"ORACLE_OWNERSHIP","R without owned AR");
    if(f.d_rvalid&&f.d_rready)begin
      require(rn<beats,"ORACLE_R_COUNT","extra read beat");
      for(int i=0;i<8;i++)require(f.d_rdata[8*i+:8]===mem(addr_t'(src)+offset+8*rn+i),"ORACLE_RDATA","source byte mismatch");
      if(f.d_rresp!=0||f.d_rid!=0||f.d_rlast!=(rn==beats-1))read_fault=1;
      rn++;rbeats++;
      if(f.d_rlast||rn==beats)begin if(read_fault)terminal(2);else stage=2;end
    end
    if(f.d_arvalid&&f.d_arready)begin
      if(!active&&cfg.fault=="duplicate_read")begin
        require(f.d_araddr===last_araddr&&f.d_arlen===last_arlen,"DUPLICATE_CONTROL_SANITY","Duplicate must repeat unchanged accepted read");
        $display("DMA_DUPLICATE_ACCEPTED kind=read bit_identical=1 address=%h length=%0d",f.d_araddr,f.d_arlen);
      end
      require(active&&stage==0,"ORACLE_AR_OWNERSHIP","unsolicited/duplicate AR or wrong command phase");
      require({32'd0,f.d_araddr}==addr_t'(src)+offset,"ORACLE_AR_ADDRESS","source/burst progression");
      require(f.d_arid==0&&f.d_arsize==3&&f.d_arburst==1&&f.d_arlen==beats-1,"ORACLE_AR_ATTR","read burst attributes");
      stage=1;ars++;
      last_araddr=f.d_araddr;last_arlen=f.d_arlen;
    end
  endfunction
  function void check_memory(dma_memory_responder responder);
    foreach(protected_bytes[a])require(responder.read_byte(a)===mem(a),"ORACLE_MEMORY","requested/guard/protected byte mismatch");
  endfunction
  function void finish_case(dma_memory_responder responder);int f;
    check_memory(responder);
    require(!active&&!ca&&!cw&&!cr,"ORACLE_ACCOUNTING","pending obligation at case end");
    require(commands==terminals+cancellations&&terminals==successes+errors,"ORACLE_ACCOUNTING","command terminal/reset totals");
    f=$fopen({"case-",label,".json"},"w");if(!f)`uvm_fatal("RESULT_IO","Cannot open case result")
    $fwrite(f,"{\"name\":\"%s\",\"commands\":%0d,\"terminals\":%0d,\"successes\":%0d,\"errors\":%0d,\"reset_cancellations\":%0d,\"acknowledgements\":%0d,\"control_rejected\":%0d,\"control_cancelled\":%0d,\"csr_reads\":%0d,\"ar\":%0d,\"aw\":%0d,\"r_beats\":%0d,\"w_beats\":%0d,\"b\":%0d,\"memory_commits\":%0d,\"comparisons\":%0d,\"resets\":%0d,\"cancelled_ar\":%0d,\"cancelled_aw\":%0d,\"cancelled_r_beats\":%0d,\"cancelled_w_beats\":%0d,\"cancelled_b_pending\":%0d,\"aw_first\":%0d,\"w_first\":%0d,\"simultaneous\":%0d,\"all_w_before_aw\":%0d}\n",label,commands,terminals,successes,errors,cancellations,acks,control_rejected,control_cancelled,reads,ars,aws,rbeats,wbeats,bs,commits,comparisons,reset_count,cancelled_ar,cancelled_aw,cancelled_rbeats,cancelled_wbeats,cancelled_b,aw_first,w_first,same_edge,all_w_before_aw);$fclose(f);
    $display("DMA_CASE_PASS name=%s commands=%0d terminals=%0d cancelled=%0d comparisons=%0d",label,commands,terminals,cancellations,comparisons);
  endfunction
endclass
