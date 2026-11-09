class dma_memory_responder extends uvm_component;
  `uvm_component_utils(dma_memory_responder)
  dma_config cfg;byte unsigned ram[addr_t];
  bit rp=0,ap=0,wl=0,committed=0,rv=0,bv=0;
  addr_t ra,wa;int partial_wait=0;int rlen,alen,ri=0,qn=0,rb=0,wb=0,cycle=0,delay_b=0,last_epoch=-1;
  bit[63:0] dataq[16];bit[7:0] strbq[16];
  bit[63:0] rd;bit[1:0] rr,br;bit[3:0] rid,bid;bit rlast;
  function new(string n,uvm_component p);super.new(n,p);endfunction
  function byte unsigned read_byte(addr_t a);
    if(a>64'hffffffff)`uvm_fatal("RESPONDER_RANGE","Byte address exceeds 32-bit space")
    return ram.exists(a)?ram[a]:initial_byte(a);
  endfunction
  function bit[63:0] read_word(addr_t a);bit[63:0] value;
    for(int i=0;i<8;i++)value[8*i+:8]=read_byte(a+i);return value;
  endfunction
  task run_phase(uvm_phase phase);
    bit awh,wh;
    forever begin
      @(cfg.vif.sample);cycle++;
      if(last_epoch!=cfg.epoch)begin ram.delete();last_epoch=cfg.epoch;end
      if(!cfg.vif.sample.reset_n)begin rp=0;ap=0;wl=0;committed=0;rv=0;bv=0;ri=0;qn=0;rb=0;wb=0;delay_b=0;partial_wait=0;end
      else begin
        if(cfg.vif.sample.d_rvalid&&cfg.vif.sample.d_rready)begin
          cfg.read_beats++;rv=0;
          if(rlast||ri==rlen)begin rp=0;rb++;end else ri++;
        end
        if(cfg.vif.sample.d_bvalid&&cfg.vif.sample.d_bready)begin
          cfg.b_accepts++;bv=0;ap=0;qn=0;wl=0;committed=0;wb++;
        end
        if(cfg.vif.sample.d_arvalid&&cfg.vif.sample.d_arready)begin
          if(rp)`uvm_fatal("RESPONDER_READ_REUSE","Unexpected second outstanding AR")
          rp=1;ra={32'd0,cfg.vif.sample.d_araddr};rlen=cfg.vif.sample.d_arlen;ri=0;
        end
        awh=cfg.vif.sample.d_awvalid&&cfg.vif.sample.d_awready;
        wh=cfg.vif.sample.d_wvalid&&cfg.vif.sample.d_wready;
        if(awh)begin
          if(ap)`uvm_fatal("RESPONDER_AW_REUSE","Unexpected outstanding AW")
          ap=1;wa={32'd0,cfg.vif.sample.d_awaddr};alen=cfg.vif.sample.d_awlen;
        end
        if(wh)begin
          if(qn>=16||wl)`uvm_fatal("RESPONDER_W_QUEUE","Early W queue overflow/extra beat")
          dataq[qn]=cfg.vif.sample.d_wdata;strbq[qn]=cfg.vif.sample.d_wstrb;
          qn++;wl=cfg.vif.sample.d_wlast;
        end
        if(ap&&wl&&!committed)begin
          if(qn!=alen+1)`uvm_fatal("RESPONDER_W_COUNT","AW length and buffered W count differ")
          if(!(cfg.scenario.write_error_burst==wb&&!cfg.scenario.commit_error))
            for(int i=0;i<qn;i++)for(int j=0;j<8;j++)if(strbq[i][j])ram[wa+8*i+j]=dataq[i][8*j+:8];
          committed=1;cfg.write_commits++;delay_b=(cfg.scenario.reset_kind==3)?60:3;
        end
      end
      @(negedge cfg.vif.clk);
      if(!cfg.vif.reset_n)begin
        cfg.vif.d_arready=0;cfg.vif.d_awready=0;cfg.vif.d_wready=0;cfg.vif.d_rvalid=0;cfg.vif.d_bvalid=0;
      end else begin
        cfg.vif.d_arready=!rp&&(cycle%3!=0);
        if(cfg.vif.d_wvalid&&cfg.vif.d_wstrb!=255&&partial_wait<4)partial_wait++;
        case(cfg.scenario.order)
          6:begin cfg.vif.d_awready=!ap;cfg.vif.d_wready=ap&&(cfg.vif.d_wstrb==255||partial_wait>=4);end
          0:begin cfg.vif.d_awready=!ap;cfg.vif.d_wready=ap&&(cycle%3!=0);end
          1:begin cfg.vif.d_awready=!ap&&qn>0;cfg.vif.d_wready=!wl&&(cycle%3!=0);end
          2:begin cfg.vif.d_awready=!ap&&wl;cfg.vif.d_wready=!wl&&(cycle%3!=0);end
          3:begin cfg.vif.d_awready=!ap&&cfg.vif.d_wvalid;cfg.vif.d_wready=!wl&&(ap||cfg.vif.d_awvalid);end
          5:begin cfg.vif.d_awready=!ap&&cfg.vif.d_wvalid;cfg.vif.d_wready=!wl&&(cycle%5!=0);end
          default:begin cfg.vif.d_awready=!ap&&(cycle%7==1);cfg.vif.d_wready=!wl&&(cycle%5!=0);end
        endcase
        if(rp&&!rv&&!cfg.freeze_data&&cfg.fault!="progress"&&(cycle%3==1))begin
          rv=1;rd=read_word(ra+8*ri);rid=(cfg.scenario.malformed==1&&ri==0)?1:0;
          rr=(cfg.scenario.read_error_burst==rb&&cfg.scenario.read_error_beat==ri)?2:0;
          rlast=(ri==rlen);
          if(cfg.scenario.malformed==3&&ri==0)rlast=1;
          if(cfg.scenario.malformed==4&&ri==rlen)rlast=0;
        end
        if(committed&&!bv&&!cfg.freeze_data)begin
          if(delay_b>0)delay_b--;else begin bv=1;br=(cfg.scenario.write_error_burst==wb)?2:0;bid=(cfg.scenario.malformed==2)?1:0;end
        end
        cfg.vif.d_rvalid=rv;cfg.vif.d_rdata=rd;cfg.vif.d_rresp=rr;cfg.vif.d_rid=rid;cfg.vif.d_rlast=rlast;
        cfg.vif.d_bvalid=bv;cfg.vif.d_bresp=br;cfg.vif.d_bid=bid;
      end
    end
  endtask
endclass
