`timescale 1ns/1ps
// Passive bounded AXI4 INCR-burst checker. FATAL=0 supports negative tests.
module axi4_burst_monitor #(parameter bit FATAL=1) (
    input logic clk, reset_n,
    input logic awvalid,awready,wvalid,wready,bvalid,bready,
    input logic arvalid,arready,rvalid,rready,
    input logic [3:0] awid,bid,arid,rid,
    input logic [31:0] awaddr,araddr,
    input logic [7:0] awlen,arlen,wstrb,
    input logic [2:0] awsize,arsize,
    input logic [1:0] awburst,arburst,bresp,rresp,
    input logic [63:0] wdata,rdata,
    input logic wlast,rlast,
    output int read_bursts,write_bursts,read_beats,write_beats,violations
);
    bit aw_stall, ar_stall, w_stall, b_stall, r_stall;
    bit read_active, write_active;
    logic [31:0] aw_hold, ar_hold;
    logic [7:0] awlen_hold, arlen_hold, wstrb_hold;
    logic [63:0] wdata_hold;
    logic wlast_hold;
    logic [3:0] awid_hold, arid_hold, bid_hold, rid_hold;
    logic [2:0] awsize_hold, arsize_hold;
    logic [1:0] awburst_hold, arburst_hold, bresp_hold, rresp_hold;
    logic [63:0] rdata_hold;
    logic rlast_hold;
    int expected_read, expected_write, received_read, received_write;
    task automatic bad(input string reason);
        violations=violations+1;
        $display("AXI4_MONITOR_VIOLATION %s",reason);
        if(FATAL) $fatal(1,"AXI4 monitor: %s",reason);
    endtask
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            read_bursts=0;write_bursts=0;read_beats=0;write_beats=0;violations=0;
            aw_stall=0;ar_stall=0;w_stall=0;b_stall=0;r_stall=0;
            read_active=0;write_active=0;
            expected_read=0;expected_write=0;received_read=0;received_write=0;
        end else begin
            if(aw_stall && (!awvalid || awaddr !== aw_hold || awlen !== awlen_hold ||
                            awid !== awid_hold || awsize !== awsize_hold ||
                            awburst !== awburst_hold))
                bad("AW changed while stalled");
            if(ar_stall && (!arvalid || araddr !== ar_hold || arlen !== arlen_hold ||
                            arid !== arid_hold || arsize !== arsize_hold ||
                            arburst !== arburst_hold))
                bad("AR changed while stalled");
            if(w_stall && (!wvalid || wdata !== wdata_hold ||
                           wstrb !== wstrb_hold || wlast !== wlast_hold))
                bad("W changed while stalled");
            if(b_stall && (!bvalid || bid !== bid_hold || bresp !== bresp_hold))
                bad("B changed while stalled");
            if(r_stall && (!rvalid || rid !== rid_hold || rdata !== rdata_hold ||
                           rresp !== rresp_hold || rlast !== rlast_hold))
                bad("R changed while stalled");
            aw_stall=awvalid&&!awready;
            if(aw_stall) begin
                aw_hold=awaddr; awlen_hold=awlen; awid_hold=awid;
                awsize_hold=awsize; awburst_hold=awburst;
            end
            ar_stall=arvalid&&!arready;
            if(ar_stall) begin
                ar_hold=araddr; arlen_hold=arlen; arid_hold=arid;
                arsize_hold=arsize; arburst_hold=arburst;
            end
            w_stall=wvalid&&!wready;
            if(w_stall) begin wdata_hold=wdata; wstrb_hold=wstrb; wlast_hold=wlast; end
            b_stall=bvalid&&!bready;
            if(b_stall) begin bid_hold=bid; bresp_hold=bresp; end
            r_stall=rvalid&&!rready;
            if(r_stall) begin
                rid_hold=rid;rdata_hold=rdata;rresp_hold=rresp;rlast_hold=rlast;
            end
            if(arvalid&&arready) begin
                if(read_active || write_active) bad("new AR while burst active");
                if(arid!=0 || arsize!=3 || arburst!=2'b01 || arlen>15 ||
                   araddr[2:0]!=0 || (int'(araddr[11:0])+(int'(arlen)+1)*8)>4096)
                    bad("unsupported or 4KiB-crossing AR");
                read_active=1;expected_read=int'(arlen)+1;received_read=0;
                read_bursts++;
            end
            if(rvalid&&rready) begin
                if(!read_active) bad("R without AR");
                else begin
                    if(rid!=0 || rlast !== (received_read==expected_read-1))
                        bad("R ID/LAST mismatch");
                    received_read++; read_beats++;
                    if(received_read==expected_read) read_active=0;
                end
            end
            if(awvalid&&awready) begin
                if(write_active || read_active) bad("new AW while burst active");
                if(awid!=0 || awsize!=3 || awburst!=2'b01 || awlen>15 ||
                   awaddr[2:0]!=0 || (int'(awaddr[11:0])+(int'(awlen)+1)*8)>4096)
                    bad("unsupported or 4KiB-crossing AW");
                write_active=1;expected_write=int'(awlen)+1;received_write=0;
                write_bursts++;
            end
            if(wvalid&&wready) begin
                if(!write_active) bad("W without AW");
                else begin
                    if(wlast !== (received_write==expected_write-1)) bad("WLAST mismatch");
                    if(wstrb==0 || (received_write<expected_write-1 && wstrb!=8'hFF))
                        bad("unsupported WSTRB for bounded memory DMA");
                    received_write++; write_beats++;
                end
            end
            if(bvalid&&bready) begin
                if(!write_active || received_write!=expected_write || bid!=0)
                    bad("B before complete write burst or wrong ID");
                write_active=0;
            end
        end
    end
    final begin
        if(FATAL && violations==0)
            $display("AMBA_AXI4_MONITOR_PASS read_bursts=%0d write_bursts=%0d read_beats=%0d write_beats=%0d",
                     read_bursts,write_bursts,read_beats,write_beats);
    end
endmodule
