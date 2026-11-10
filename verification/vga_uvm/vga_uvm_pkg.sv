`timescale 1ns/1ps
package vga_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `uvm_analysis_imp_decl(_verdict)
  `uvm_analysis_imp_decl(_intent)
  typedef struct packed {
    bit rising,reset_rise,control_only,initial_sample;
    logic [22:0] controls;
    longint unsigned edge_time_ns;
    logic hs,vs,av;
    logic [11:0] rgb;
  } vga_observation;
  typedef struct packed {
    int unsigned observations,clocks,control_only,initial_samples,comparisons;
    int unsigned enabled_writes,valid_writes,ignored_writes,reset_writes;
    int unsigned pixel_advances,pixel_samples,active_samples,hs_low,vs_low;
    int unsigned complete_lines,complete_frames,reset_edges,hits_at_all_phases;
  } vga_counts;

  class vga_raster_model;
    int h=0,v=0,d=0;
    function bit advance(input bit clock_rise,input bit reset);
      if(reset) begin h=0;v=0;d=0;return 0;end
      if(!clock_rise) return 0;
      if(d!=3) begin d++;return 0;end
      d=0;
      if(h<799) h++;else begin h=0;if(v<524)v++;else v=0;end
      return 1;
    endfunction
  endclass
  class vga_frame_model;
    byte unsigned mem[4800];
    function new();
      for(int row=0;row<60;row++) for(int col=0;col<80;col++) begin
        byte unsigned p;
        p=col<=26?224:(col<=53?28:3);
        if(row>=24 && row<=34) begin
          bit letter_d,letter_i,letter_l;
          letter_d=(col==28)||((row==24||row==34)&&col>=28&&col<=33)||(col==34&&row>24&&row<34);
          letter_i=(col==40)||((row==24||row==34)&&col>=38&&col<=42);
          letter_l=(col==46)||(row==34&&col>=46&&col<=52);
          if(letter_d||letter_i||letter_l)p=255;
        end
        mem[row*80+col]=p;
      end
    endfunction
    function void accept(input int address,input byte unsigned data);
      if(address<4800)mem[address]=data;
    endfunction
    function logic[11:0] expand(input byte unsigned p);
      logic[3:0] r,g,b;
      r=((p/32)%8)*2+((p/128)%2);
      g=((p/4)%8)*2+((p/16)%2);
      b=(p%4)*5;
      return {r,g,b};
    endfunction
  endclass

  class vga_scoreboard extends uvm_component;
    `uvm_component_utils(vga_scoreboard)
    uvm_analysis_imp#(vga_observation,vga_scoreboard) observed;
    uvm_analysis_imp_verdict#(vga_observation,vga_scoreboard) verdict;
    uvm_analysis_imp_intent#(logic[22:0],vga_scoreboard) intention;
    logic [22:0] planned_controls={1'b1,22'd0};
    virtual vga_bus vif;
    vga_raster_model raster;
    vga_frame_model fb;
    vga_counts total,start_counts;
    string current_case="",pending_id="",pending_detail="";
    int case_count=0,frame_fd=0,recorded_pixels=0,accepted_fd=0;
    longint unsigned last_clock_edge_ps=0;
    bit record_frame=0,frame_started=0;
    bit address_seen[4800],color_seen[256];
    int distinct_addresses=0,distinct_colors=0;
    int phase_writes[4],start_phase_writes[4];
    bit line_complete=0,frame_complete=0;
    function new(string name,uvm_component parent);
      super.new(name,parent);observed=new("observed",this);verdict=new("verdict",this);intention=new("intention",this);
      raster=new;fb=new;total='0;start_counts='0;
      foreach(address_seen[i])address_seen[i]=0;
      foreach(color_seen[i])color_seen[i]=0;
      foreach(phase_writes[i])phase_writes[i]=0;
    endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual vga_bus)::get(this,"","vif",vif))`uvm_fatal("VGA_CONFIG","vif missing")
      accepted_fd=$fopen("accepted-writes.csv","w");
      if(!accepted_fd)`uvm_fatal("VGA_IO","accepted-write log unavailable")
      $fwrite(accepted_fd,"time_ps,reset,address,data,valid\n");
    endfunction
    function void write_intent(logic[22:0] value);planned_controls=value;endfunction
    function void mark(input string name);
      if(current_case!="") finish_case();
      current_case=name;start_counts=total;distinct_addresses=0;distinct_colors=0;
      foreach(address_seen[i])address_seen[i]=0;
      foreach(color_seen[i])color_seen[i]=0;
      foreach(phase_writes[i])start_phase_writes[i]=phase_writes[i];
      $display("VGA_CASE_START name=%s time=%0t",name,$time);
    endfunction
    function void finish_case();
      vga_counts c;int fd;
      c='0;
      // Packed subtraction is not fieldwise; explicitly reconcile each measure.
      c.observations=total.observations-start_counts.observations;
      c.clocks=total.clocks-start_counts.clocks;c.control_only=total.control_only-start_counts.control_only;
      c.initial_samples=total.initial_samples-start_counts.initial_samples;
      c.comparisons=total.comparisons-start_counts.comparisons;
      c.enabled_writes=total.enabled_writes-start_counts.enabled_writes;
      c.valid_writes=total.valid_writes-start_counts.valid_writes;c.ignored_writes=total.ignored_writes-start_counts.ignored_writes;
      c.reset_writes=total.reset_writes-start_counts.reset_writes;
      c.pixel_advances=total.pixel_advances-start_counts.pixel_advances;
      c.pixel_samples=total.pixel_samples-start_counts.pixel_samples;c.active_samples=total.active_samples-start_counts.active_samples;
      c.hs_low=total.hs_low-start_counts.hs_low;c.vs_low=total.vs_low-start_counts.vs_low;
      c.complete_lines=total.complete_lines-start_counts.complete_lines;
      c.complete_frames=total.complete_frames-start_counts.complete_frames;c.reset_edges=total.reset_edges-start_counts.reset_edges;
      if(c.observations!=c.clocks+c.control_only+c.initial_samples || c.comparisons!=6*c.observations ||
        c.enabled_writes!=c.valid_writes+c.ignored_writes)`uvm_fatal("VGA_ACCOUNTING",current_case)
      fd=$fopen({"case-",current_case,".json"},"w");
      $fwrite(fd,"{\"name\":\"%s\",\"observations\":%0d,\"clocks\":%0d,\"control_only\":%0d,\"initial_samples\":%0d,\"comparisons\":%0d,\"enabled_writes\":%0d,\"valid_writes\":%0d,\"ignored_writes\":%0d,\"reset_writes\":%0d,\"pixel_advances\":%0d,\"pixel_samples\":%0d,\"active_samples\":%0d,\"hs_low\":%0d,\"vs_low\":%0d,\"complete_lines\":%0d,\"complete_frames\":%0d,\"reset_edges\":%0d,\"distinct_addresses\":%0d,\"distinct_colors\":%0d,\"phase_writes\":[%0d,%0d,%0d,%0d]}\n",
        current_case,c.observations,c.clocks,c.control_only,c.initial_samples,c.comparisons,c.enabled_writes,c.valid_writes,c.ignored_writes,c.reset_writes,c.pixel_advances,c.pixel_samples,c.active_samples,c.hs_low,c.vs_low,c.complete_lines,c.complete_frames,c.reset_edges,distinct_addresses,distinct_colors,
        phase_writes[0]-start_phase_writes[0],phase_writes[1]-start_phase_writes[1],phase_writes[2]-start_phase_writes[2],phase_writes[3]-start_phase_writes[3]);
      $fclose(fd);case_count++;
      $display("VGA_CASE_PASS name=%s observations=%0d comparisons=%0d clocks=%0d writes=%0d ignored=%0d frames=%0d time=%0t",current_case,c.observations,c.comparisons,c.clocks,c.valid_writes,c.ignored_writes,c.complete_frames,$time);
    endfunction
    function void write(vga_observation o);
      bit reset,we,advance,ea,eh,ev;int address,index,old_d,old_h,old_v;byte unsigned data,p;
      logic[11:0] ergb;
      reset=o.controls[22];we=o.controls[21];address=o.controls[20:8];data=o.controls[7:0];
      pending_id="";pending_detail="";
      if(o.controls!==planned_controls) pending_id="VGA_INTENT";
      total.observations++;total.comparisons+=6;
      if(o.initial_sample)total.initial_samples++;
      else if(o.rising)total.clocks++;else total.control_only++;
      old_d=raster.d;old_h=raster.h;old_v=raster.v;
      if(o.rising)last_clock_edge_ps=o.edge_time_ns*1000;
      if(o.reset_rise)begin total.reset_edges++;line_complete=0;frame_complete=0;end
      if(o.rising && we)begin
        $fwrite(accepted_fd,"%0d,%0d,%0d,%0d,%0d\n",o.edge_time_ns*1000,reset,address,data,address<4800);
        total.enabled_writes++;
        if(reset)total.reset_writes++;
        else phase_writes[old_d]++;
        if(address<4800)begin fb.accept(address,data);total.valid_writes++;end
        else total.ignored_writes++;
      end
      advance=raster.advance(o.rising,reset);
      if(advance)begin
        total.pixel_advances++;
        if(raster.h==0)begin
          if(line_complete)total.complete_lines++;
          line_complete=1;
          if(raster.v==0)begin if(frame_complete)total.complete_frames++;frame_complete=1;end
        end
      end
      // A reset-aligned interval is a complete frame from position 0 onward.
      if(reset)begin line_complete=1;frame_complete=1;end
      ea=raster.h<640 && raster.v<480;eh=!(raster.h>=656 && raster.h<=751);ev=!(raster.v>=490 && raster.v<=491);
      index=(raster.v/8)*80+(raster.h/8);p=ea?fb.mem[index]:0;ergb=fb.expand(p);
      vif.check_reset=reset;vif.expected_h=eh;vif.expected_v=ev;vif.expected_active=ea;vif.expected_rgb=ergb;
      if(pending_id=="")begin
        if(reset && {o.hs,o.vs,o.av,o.rgb}!=={3'b111,ergb})pending_id="VGA_RESET";
        else if(o.hs!==eh)pending_id="VGA_HSYNC";
        else if(o.vs!==ev)pending_id="VGA_VSYNC";
        else if(o.av!==ea)pending_id="VGA_ACTIVE";
        else if(!ea && o.rgb!==12'h0)pending_id="VGA_BLANK";
        else if(o.rgb!==ergb)pending_id="VGA_RGB";
      end
      if(pending_id!="")pending_detail=$sformatf("case=%s h=%0d v=%0d div=%0d expected=%b%b%b/%h actual=%b%b%b/%h controls=%h intended=%h",current_case,raster.h,raster.v,raster.d,eh,ev,ea,ergb,o.hs,o.vs,o.av,o.rgb,o.controls,planned_controls);
      if(ea)begin
        if(!address_seen[index])begin address_seen[index]=1;distinct_addresses++;end
        if(!color_seen[p])begin color_seen[p]=1;distinct_colors++;end
      end
      if(o.rising && !reset && raster.d==1)begin
        total.pixel_samples++;
        if(ea)total.active_samples++;
        if(!o.hs)total.hs_low++;if(!o.vs)total.vs_low++;
        if(record_frame && recorded_pixels<420000)begin
          if(!frame_started)begin
            frame_fd=$fopen("actual-frame.rgb444","wb");frame_started=1;
            $display("VGA_FRAME_CAPTURE_START time=%0t clock=%0d",$time,total.clocks);
          end
          // Four actual pin bytes per raster position, in chronological order.
          $fwrite(frame_fd,"%c%c%c%c",{4'b0,o.rgb[11:8]},{4'b0,o.rgb[7:4]},
            {4'b0,o.rgb[3:0]},{5'b0,o.hs,o.vs,o.av});
          recorded_pixels++;
          if(recorded_pixels==420000)begin $fclose(frame_fd);frame_fd=0;$display("VGA_FRAME_CAPTURE_PASS pixels=%0d time=%0t",recorded_pixels,$time);end
        end
      end
    endfunction
    function void write_verdict(vga_observation o);
      if(pending_id!="")`uvm_fatal(pending_id,pending_detail)
    endfunction
    function void final_results();
      int fd;
      finish_case();
      if(vif.assertion_detections!=0)`uvm_fatal("VGA_ASSERTION_COUNT","Unexpected assertion detection")
      fd=$fopen("totals.json","w");
      $fwrite(fd,"{\"cases\":%0d,\"observations\":%0d,\"comparisons\":%0d,\"clocks\":%0d,\"writes\":%0d,\"ignored\":%0d,\"frames\":%0d,\"frame_pixels\":%0d,\"assertion_samples\":%0d,\"end_tick_ps\":%0d,\"last_clock_edge_ps\":%0d,\"phase_writes\":[%0d,%0d,%0d,%0d]}\n",case_count,total.observations,total.comparisons,total.clocks,total.valid_writes,total.ignored_writes,total.complete_frames,recorded_pixels,vif.assertion_samples,longint'($realtime*1000),last_clock_edge_ps,phase_writes[0],phase_writes[1],phase_writes[2],phase_writes[3]);$fclose(fd);$fclose(accepted_fd);
      $display("VGA_UVM_PASS cases=%0d observations=%0d comparisons=%0d assertions=0 seed=0x28A6BEEF",case_count,total.observations,total.comparisons);
    endfunction
  endclass

  typedef enum{MARK,SET,RUN,POSITION,FRAMES,ASYNC_PENDING,COINCIDENT,WAVE,RECORD,ALIGN}vga_operation;
  class vga_item extends uvm_sequence_item;
    `uvm_object_utils(vga_item)
    vga_operation op;string label;int a,b,c,d;
    function new(string name="vga_item");super.new(name);endfunction
  endclass
  class vga_sequencer extends uvm_sequencer#(vga_item);
    `uvm_component_utils(vga_sequencer)
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
  endclass
  class vga_driver extends uvm_driver#(vga_item);
    `uvm_component_utils(vga_driver)
    virtual vga_bus vif;vga_scoreboard sb;bit driver_alias;
    uvm_analysis_port#(logic[22:0]) intended;
    int intent_fd=0;
    function new(string name,uvm_component parent);super.new(name,parent);intended=new("intended",this);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);if(!uvm_config_db#(virtual vga_bus)::get(this,"","vif",vif))`uvm_fatal("VGA_CONFIG","vif missing")
      driver_alias=$test$plusargs("DRIVER_ALIAS");
      intent_fd=$fopen("intents.csv","w");if(!intent_fd)`uvm_fatal("VGA_IO","intent log unavailable")
      $fwrite(intent_fd,"time_ps,reset,we,address,data\n0,1,0,0,0\n");
    endfunction
    function void record_intent(input logic[22:0] ctrl);
      intended.write(ctrl);
      $fwrite(intent_fd,"%0t,%0d,%0d,%0d,%0d\n",$realtime,ctrl[22],ctrl[21],ctrl[20:8],ctrl[7:0]);
    endfunction
    function void drive(input bit reset,input bit we,input int addr,input int data);
      logic[22:0] ctrl;
      ctrl={reset,we,13'(addr),8'(data)};record_intent(ctrl);
      if(driver_alias)ctrl[20:8]=ctrl[20:8]&13'hff;
      vif.controls=ctrl;
    endfunction
    task clock_edges(input int n);repeat(n)begin @(posedge vif.clk);#2;end endtask
    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        case(req.op)
          MARK:sb.mark(req.label);
          SET:begin @(negedge vif.clk);#2;drive(req.a,req.b,req.c,req.d);#1.2;end
          RUN:clock_edges(req.a);
          POSITION:begin
            while(!(sb.raster.h==req.a && sb.raster.v==req.b && sb.raster.d==req.c))clock_edges(1);
          end
          FRAMES:begin int target;target=sb.total.complete_frames+req.a;while(sb.total.complete_frames<target)clock_edges(1);end
          ALIGN:begin clock_edges(1);while(sb.raster.d!=req.a)clock_edges(1);end
          ASYNC_PENDING:begin
            @(negedge vif.clk);#2;drive(0,1,0,8'h5a);#1.5;drive(1,1,0,8'h5a);#1.2;
          end
          COINCIDENT:begin
            @(negedge vif.clk);#2;drive(0,1,0,8'ha6);
            @(posedge vif.clk);record_intent({2'b11,13'd0,8'ha6});vif.controls<={2'b11,13'd0,8'ha6};#2;
          end
          WAVE:begin
            vif.capture=req.a;
            if(req.a)$display("VGA_WAVE_START name=%s time=%0t",req.label,$time);
            else $display("VGA_WAVE_END name=%s time=%0t",req.label,$time);
          end
          RECORD:sb.record_frame=req.a;
        endcase
        seq_item_port.item_done();
      end
    endtask
  endclass
  class vga_monitor extends uvm_component;
    `uvm_component_utils(vga_monitor)
    virtual vga_bus vif;
    logic [30:0] previous_signature='x;
    uvm_analysis_port#(vga_observation)ap,checked;
    function new(string name,uvm_component parent);super.new(name,parent);ap=new("ap",this);checked=new("checked",this);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);if(!uvm_config_db#(virtual vga_bus)::get(this,"","vif",vif))`uvm_fatal("VGA_CONFIG","vif missing")
    endfunction
    task publish(input bit rising,input bit rr,input bit initial_sample);
      vga_observation o;
      logic [30:0] signature;bit evaluate;
      o.rising=rising;o.reset_rise=rr;o.initial_sample=initial_sample;o.control_only=!rising&&!initial_sample;
      o.controls={vif.reset,vif.sram_we,vif.sram_addr,vif.sram_data_in};o.edge_time_ns=$time;
      #0.999;
      o.hs=vif.hsync;o.vs=vif.vsync;o.av=vif.active_video;o.rgb={vif.red,vif.green,vif.blue};
      ap.write(o);
      signature={vif.check_reset,vif.expected_h,vif.expected_v,vif.expected_active,vif.expected_rgb,o.hs,o.vs,o.av,o.rgb};
      // All assertions are history-free output predicates. A constant
      // signature has the same truth value as its preceding checked sample.
      // Every input-clock observation still receives the full scoreboard check.
      evaluate=(signature!==previous_signature)||o.control_only||o.initial_sample||(o.rising&&o.controls[21]);
      previous_signature=signature;
      if(evaluate)begin
        // Expectations precede Preponed sampling in a distinct time slot.
        #0.001;vif.sample_tick=~vif.sample_tick;vif.assertion_samples++;
        #0.01;
      end
      checked.write(o);
    endtask
    task run_phase(uvm_phase phase);
      bit previous_clk,previous_reset,changed,rising,rr;logic[22:0] previous_controls;
      #0.001;previous_clk=vif.clk;previous_reset=vif.reset;previous_controls=vif.controls;
      publish(0,vif.reset,1);
      forever begin
        @(vif.clk or vif.controls);#0.001;
        rising=vif.clk&&!previous_clk;rr=vif.reset&&!previous_reset;changed=vif.controls!==previous_controls;
        previous_clk=vif.clk;previous_reset=vif.reset;previous_controls=vif.controls;
        if(rising||changed)publish(rising,rr,0);
      end
    endtask
  endclass
  class vga_sequence extends uvm_sequence#(vga_item);
    `uvm_object_utils(vga_sequence)
    string group="smoke";
    function new(string name="vga_sequence");super.new(name);endfunction
    task send(input vga_operation op,input string label="",input int a=0,b=0,c=0,d=0);
      vga_item item;item=vga_item::type_id::create("item");start_item(item);item.op=op;item.label=label;item.a=a;item.b=b;item.c=c;item.d=d;finish_item(item);
    endtask
    task mark(input string name);send(MARK,name);endtask
    task set(input bit r,input bit we,input int addr=0,input int data=0);send(SET,"",r,we,addr,data);endtask
    task clocks(input int n);send(RUN,"",n);endtask
    task pos(input int h,input int v,input int d=0);send(POSITION,"",h,v,d);endtask
    task wave(input string name,input bit on);send(WAVE,name,on);endtask
    function int pattern(input int addr,input int mode);return mode==0?(addr&255):(((addr>>8)<<3)|((~addr)&7));endfunction
    task fill(input int mode);
      for(int i=0;i<4800;i++)set(1,1,i,pattern(i,mode));clocks(1);set(1,0);
    endtask
    task invalid(input int mode);
      int addresses[7]='{4800,4801,5119,5120,6144,7935,8191};
      foreach(addresses[i])set(1,1,addresses[i],pattern(addresses[i]%4800,mode)^255);
      clocks(1);set(1,0);
    endtask
    task body();
      if(group=="smoke")begin
        mark("smoke");clocks(2);set(1,1,0,8'ha5);clocks(2);set(1,0);set(0,0);clocks(80);return;
      end
      if(group=="horizontal")begin mark("horizontal");set(0,0);pos(654,0);clocks(420);return;end
      if(group=="vertical")begin mark("vertical");set(0,0);pos(0,489);clocks(4000);return;end
      if(group=="framewrap")begin mark("framewrap");set(0,0);send(FRAMES,"",1);clocks(8);return;end
      if(group=="scale")begin mark("scale");set(1,1,0,8'ha5);set(1,1,1,8'h3c);clocks(1);set(0,0);clocks(100);return;end
      if(group=="row")begin mark("row");set(0,0);pos(4,8);return;end
      if(group=="invalid")begin mark("invalid");clocks(1);set(1,1,4800,8'h5a);clocks(1);set(1,0);clocks(4);return;end
      if(group=="phase")begin mark("phase");set(0,0);send(ALIGN,"",1);set(0,1,0,8'ha5);clocks(1);set(0,0);clocks(4);return;end
      if(group=="intent")begin mark("intent");set(1,1,256,8'h5a);clocks(1);return;end
      if(group!="functional")`uvm_fatal("VGA_GROUP",group)
      mark("initial_image");clocks(2);send(RECORD,"",1);set(0,0);
      mark("horizontal_boundaries");pos(638,0);wave("horizontal",1);pos(754,0);wave("horizontal",0);
      mark("line_wrap");pos(4,1);
      mark("vertical_active_boundary");pos(796,479);pos(4,480);
      mark("vertical_sync_boundaries");pos(796,489);wave("vertical_sync",1);pos(4,492);wave("vertical_sync",0);
      mark("frame_wrap");pos(796,524);wave("frame_wrap",1);pos(4,0);wave("frame_wrap",0);
      mark("consecutive_second_frame");send(FRAMES,"",1);send(RECORD,"",0);
      mark("pattern_low_load");fill(0);
      mark("invalid_low_sideeffects");invalid(0);
      mark("pattern_low_scan");set(0,0);send(FRAMES,"",1);
      mark("pattern_high_load");fill(1);
      mark("invalid_high_sideeffects");invalid(1);
      mark("pattern_high_scan");set(0,0);send(FRAMES,"",1);
      mark("all_rgb332");for(int c=0;c<256;c++)begin set(1,1,0,c);clocks(1);end set(1,0);
      mark("back_to_back_edges");set(1,1,0,8'h11);set(1,1,79,8'h22);set(1,1,80,8'h33);set(1,1,4799,8'h44);clocks(1);set(1,0);
      mark("held_enable");set(1,1,1,8'h7c);clocks(4);set(1,0);
      mark("inactive_input_changes");set(1,0,0,8'hff);set(1,0,8191,0);clocks(2);
      mark("divider_phase_writes");set(0,0);
      for(int p=0;p<4;p++)begin send(ALIGN,"",p);set(0,1,0,8'ha0+p);clocks(1);set(0,0);end
      mark("current_previous_future");set(1,0);set(0,0);pos(100,16);wave("current_pixel",1);
      set(0,1,172,8'h9b);clocks(1);set(0,0);wave("current_pixel",0);
      set(0,1,0,8'h48);set(0,1,1000,8'h6d);clocks(1);set(0,0);pos(324,96);
      mark("horizontal_blanking_write");pos(660,96);set(0,1,1001,8'hd2);clocks(1);set(0,0);pos(332,97);
      mark("active_reset");set(1,0);clocks(2);set(0,0);clocks(80);set(1,0);clocks(1);set(0,0);
      mark("hsync_reset");pos(660,0);set(1,0);clocks(1);set(0,0);
      mark("vertical_blanking_write_and_sync_reset");pos(0,490);set(0,1,0,8'ha5);set(0,1,1,8'h3c);clocks(1);set(0,0);set(1,0);clocks(2);set(0,0);pos(12,0);
      mark("asynchronous_pending_write");wave("async_reset",1);send(ASYNC_PENDING);clocks(1);
      mark("held_reset_writes");set(1,1,0,8'hc3);clocks(3);set(1,0);wave("async_reset",0);
      mark("coincident_reset_write");send(COINCIDENT);clocks(1);set(1,0);
      mark("release_first_four_clocks");set(0,0);clocks(4);
      mark("repeated_reset_retention");set(1,0);clocks(1);set(0,0);clocks(4);set(1,0);clocks(1);set(0,0);
      mark("post_reset_operation");clocks(160);
    endtask
  endclass
  class vga_environment extends uvm_env;
    `uvm_component_utils(vga_environment)
    vga_driver driver;vga_monitor monitor;vga_sequencer sequencer;vga_scoreboard scoreboard;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);driver=vga_driver::type_id::create("driver",this);monitor=vga_monitor::type_id::create("monitor",this);
      sequencer=vga_sequencer::type_id::create("sequencer",this);scoreboard=vga_scoreboard::type_id::create("scoreboard",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);monitor.ap.connect(scoreboard.observed);monitor.checked.connect(scoreboard.verdict);driver.intended.connect(scoreboard.intention);driver.sb=scoreboard;
    endfunction
  endclass
  class vga_test extends uvm_test;
    `uvm_component_utils(vga_test)
    vga_environment env;
    function new(string name,uvm_component parent);super.new(name,parent);endfunction
    function void build_phase(uvm_phase phase);super.build_phase(phase);env=vga_environment::type_id::create("env",this);endfunction
    task run_phase(uvm_phase phase);
      vga_sequence sequence_;phase.raise_objection(this);sequence_=vga_sequence::type_id::create("sequence_");
      if(!$value$plusargs("GROUP=%s",sequence_.group))sequence_.group="smoke";
      sequence_.start(env.sequencer);env.scoreboard.final_results();phase.drop_objection(this);
    endtask
  endclass
endpackage
