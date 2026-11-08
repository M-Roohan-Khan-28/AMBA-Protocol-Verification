`timescale 1ns/1ps
// Checker qualification, NOT a DUT test. All stimulus uses public pins and the
// production passive monitor/scoreboard/SVA. Duplicate AXI transfers are legal
// and bit-identical; only their one-CPU-request association is wrong.
package axil_request_control_pkg;
  import uvm_pkg::*;import axil_uvm_pkg::*;
  `include "uvm_macros.svh"
  class axil_request_control_test extends uvm_test;
    `uvm_component_utils(axil_request_control_test)
    axil_config cfg;axil_monitor monitor;axil_scoreboard scoreboard;
    int expected=0,aborts=0,mode=0,serial=0;
    localparam bit[31:0] DATA=32'h28a6beef;
    function new(string n,uvm_component p);super.new(n,p);endfunction
    function void build_phase(uvm_phase phase);
      if(!uvm_config_db#(axil_config)::get(this,"","cfg",cfg)) `uvm_fatal("CFG","Missing configuration")
      monitor=axil_monitor::type_id::create("monitor",this);monitor.cfg=cfg;
      scoreboard=axil_scoreboard::type_id::create("scoreboard",this);scoreboard.cfg=cfg;
      if(!$value$plusargs("CONTROL=%d",mode)||mode<0||mode>2) `uvm_fatal("CFG","CONTROL must be 0, 1 or 2")
    endfunction
    function void connect_phase(uvm_phase phase);monitor.observed.connect(scoreboard.analysis_export);endfunction
    task tick();@(negedge cfg.vif.clk);endtask
    task idle();
      cfg.vif.req_valid=0;cfg.vif.response_valid=0;
      cfg.vif.awvalid=0;cfg.vif.wvalid=0;cfg.vif.arvalid=0;cfg.vif.bvalid=0;cfg.vif.rvalid=0;
      cfg.vif.req_ready=1;cfg.vif.awready=1;cfg.vif.wready=1;cfg.vif.arready=1;cfg.vif.bready=1;cfg.vif.rready=1;
      cfg.vif.awprot=0;cfg.vif.arprot=0;cfg.vif.bresp=0;cfg.vif.rresp=0;cfg.vif.response_error=0;
      cfg.vif.req_write=0;cfg.vif.req_addr=BASE;cfg.vif.req_wdata=DATA;cfg.vif.req_wstrb=15;
      cfg.vif.awaddr=BASE;cfg.vif.wdata=DATA;cfg.vif.wstrb=15;cfg.vif.araddr=BASE;
      cfg.vif.rdata=DATA;cfg.vif.response_data=DATA;
    endtask
    task reset_control();
      idle();cfg.vif.reset_n=0;repeat(2)tick();cfg.vif.reset_n=1;tick();
    endtask
    task request(bit wr,bit[31:0] addr=BASE,bit[3:0] strb=15);
      cfg.vif.req_write=wr;cfg.vif.req_addr=addr;cfg.vif.req_wdata=DATA;cfg.vif.req_wstrb=strb;
      cfg.vif.req_valid=1;tick();cfg.vif.req_valid=0;
    endtask
    task aw(bit[31:0] addr=BASE);
      cfg.vif.awaddr=addr;cfg.vif.awvalid=1;cfg.vif.awready=0;tick();
      cfg.vif.awready=1;tick();cfg.vif.awvalid=0;
    endtask
    task wd(bit[3:0] strb=15);
      cfg.vif.wdata=DATA;cfg.vif.wstrb=strb;cfg.vif.wvalid=1;cfg.vif.wready=0;tick();
      cfg.vif.wready=1;tick();cfg.vif.wvalid=0;
    endtask
    task address_data(bit[31:0] addr=BASE,bit[3:0] strb=15);
      case(serial%3)
        0:begin aw(addr);wd(strb);end
        1:begin wd(strb);aw(addr);end
        2:begin
          cfg.vif.awaddr=addr;cfg.vif.wdata=DATA;cfg.vif.wstrb=strb;
          cfg.vif.awvalid=1;cfg.vif.wvalid=1;tick();cfg.vif.awvalid=0;cfg.vif.wvalid=0;
        end
      endcase
      serial++;
    endtask
    task b(bit error=0);
      cfg.vif.bvalid=1;cfg.vif.bresp=error?2:0;tick();cfg.vif.bvalid=0;
    endtask
    task ar(bit[31:0] addr=BASE);
      cfg.vif.araddr=addr;cfg.vif.arvalid=1;cfg.vif.arready=0;tick();
      cfg.vif.arready=1;tick();cfg.vif.arvalid=0;
    endtask
    task r(bit error=0);
      cfg.vif.rvalid=1;cfg.vif.rresp=error?2:0;cfg.vif.rdata=error?0:DATA;
      tick();cfg.vif.rvalid=0;
    endtask
    task complete(bit error=0);
      cfg.vif.response_valid=1;cfg.vif.response_error=error;cfg.vif.response_data=error?0:DATA;
      tick();cfg.vif.response_valid=0;expected++;
    endtask
    task normal(bit wr,bit[31:0] addr=BASE,bit[3:0] strb=15,bit error=0);
      request(wr,addr,strb);
      if(wr)begin address_data(addr,strb);b(error);end
      else begin ar(addr);r(error);end
      complete(error);
    endtask
    task run_phase(uvm_phase phase);
      phase.raise_objection(this);tick();reset_control();
      // Exercise the production scoreboard's unmodified requirement gates.
      for(int i=0;i<16;i++)normal(1,BASE+4*i);
      for(int i=0;i<16;i++)normal(0,BASE+4*i);
      for(int mask=0;mask<16;mask++)normal(1,BASE,4'(mask));
      normal(1,BASE+64,15,1);normal(0,BASE+64,15,1);
      // Cancel at each CPU/bus association stage, including AFTER the bus
      // response but BEFORE CPU completion. All writes keep data unchanged.
      for(int stage=0;stage<8;stage++)begin
        request(stage<5);
        case(stage)
          0:;
          1:aw();
          2:wd();
          3:address_data();
          4:begin address_data();b();end
          5:;
          6:ar();
          7:begin ar();r();end
        endcase
        reset_control();aborts++;
      end
      if(mode!=0)begin
        request(mode==1);
        if(mode==1)begin address_data();b();end else begin ar();r();end
        $display("AXIL_REQUEST_CONTROL_INJECT adapter=%0d mode=%0d assertions=%0d data=%h",cfg.adapter,mode,cfg.vif.assertion_failures,DATA);
        // The first bus response has been accepted, but CPU completion has
        // not happened. Repeat the exact legal transaction with no new CPU request.
        if(mode==1)begin address_data();b();end else begin ar();r();end
        complete();
      end
      repeat(4)tick();phase.drop_objection(this);
    endtask
    function void check_phase(uvm_phase phase);
      // Same CPU accounting gate as the reviewed original axil_test. The
      // production scoreboard also runs its full check_phase automatically.
      if(scoreboard.completions!=expected||scoreboard.requests!=expected+aborts||
         scoreboard.discarded!=aborts||cfg.vif.assertion_failures!=0)
        `uvm_fatal("CONTROL_COUNTS","CPU/reset count or AXI assertion mismatch")
    endfunction
    function void report_phase(uvm_phase phase);
      uvm_report_server server=uvm_report_server::get_server();
      if(server.get_severity_count(UVM_ERROR)||server.get_severity_count(UVM_FATAL)) `uvm_fatal("SUMMARY","UVM errors")
      $display("AXIL_REQUEST_CONTROL_PASS adapter=%0d mode=%0d requests=%0d completions=%0d writes=%0d reads=%0d cancelled=%0d assertions=0",
        cfg.adapter,mode,scoreboard.requests,scoreboard.completions,scoreboard.writes,scoreboard.reads,scoreboard.discarded);
    endfunction
  endclass
endpackage

module axil_request_control;
  import uvm_pkg::*;import axil_uvm_pkg::*;import axil_request_control_pkg::*;
  bit clk=0;always #5 clk=~clk;
  axil_bus bus(clk);axil_assertions assertions(bus);
  initial begin
    axil_config cfg;cfg=axil_config::type_id::create("cfg");
    cfg.adapter=`AXIL_ADAPTER;cfg.vif=bus;
    uvm_config_db#(axil_config)::set(null,"*","cfg",cfg);
    run_test("axil_request_control_test");
  end
  initial begin #100000;$fatal(1,"Request-control watchdog");end
endmodule
