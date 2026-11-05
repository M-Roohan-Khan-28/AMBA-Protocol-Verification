`timescale 1ns/1ps
// Passive five-channel AXI4-Lite monitor, independent of the DUT adapter.
module axi_lite_monitor (
    input logic clk, reset_n,
    input logic awvalid, awready, wvalid, wready, bvalid, bready,
    input logic arvalid, arready, rvalid, rready,
    input logic [31:0] awaddr, wdata, araddr, rdata,
    input logic [3:0] wstrb,
    input logic [1:0] bresp, rresp,
    output int aw_count, w_count, b_count, ar_count, r_count,
    output int violations
);
    bit aw_stall, w_stall, b_stall, ar_stall, r_stall;
    logic [31:0] aw_hold, w_hold, ar_hold, r_hold;
    logic [3:0] strb_hold;
    logic [1:0] bresp_hold, rresp_hold;
    int bad;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            aw_count<=0; w_count<=0; b_count<=0; ar_count<=0; r_count<=0;
            violations<=0;
            aw_stall<=0; w_stall<=0; b_stall<=0; ar_stall<=0; r_stall<=0;
        end else begin
            bad=0;
            if (aw_stall && (!awvalid || awaddr !== aw_hold)) bad++;
            if (w_stall && (!wvalid || wdata !== w_hold || wstrb !== strb_hold)) bad++;
            if (b_stall && (!bvalid || bresp !== bresp_hold)) bad++;
            if (ar_stall && (!arvalid || araddr !== ar_hold)) bad++;
            if (r_stall && (!rvalid || rdata !== r_hold || rresp !== rresp_hold)) bad++;
            if (bvalid && bready && (b_count >= aw_count || b_count >= w_count)) bad++;
            if (rvalid && rready && r_count >= ar_count) bad++;
            if (bad != 0) begin
                violations <= violations + bad;
                $display("AXIL_MONITOR_VIOLATION count=%0d",bad);
            end
            aw_stall <= awvalid && !awready; if (awvalid && !awready) aw_hold<=awaddr;
            w_stall <= wvalid && !wready;
            if (wvalid && !wready) begin w_hold<=wdata; strb_hold<=wstrb; end
            b_stall <= bvalid && !bready; if (bvalid && !bready) bresp_hold<=bresp;
            ar_stall <= arvalid && !arready; if (arvalid && !arready) ar_hold<=araddr;
            r_stall <= rvalid && !rready;
            if (rvalid && !rready) begin r_hold<=rdata; rresp_hold<=rresp; end
            if (awvalid && awready) aw_count <= aw_count+1;
            if (wvalid && wready) w_count <= w_count+1;
            if (bvalid && bready) b_count <= b_count+1;
            if (arvalid && arready) ar_count <= ar_count+1;
            if (rvalid && rready) r_count <= r_count+1;
        end
    end
endmodule
