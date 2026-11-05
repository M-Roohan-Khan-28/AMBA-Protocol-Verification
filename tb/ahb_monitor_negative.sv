`timescale 1ns/1ps
module ahb_monitor_negative;
    logic clk=0;
    always #5 clk=~clk;
    logic reset_n=0, select=0, ready=1, readyout=1, resp=0, write=0;
    logic [7:0] addr=0;
    logic [1:0] trans=0;
    logic [2:0] size=2;
    int addresses, violations;
    ahb_lite_monitor mon(.*);
    initial begin
        repeat(2) @(negedge clk);
        reset_n=1; ready=0; addr=8'h04; trans=2'b10; select=1;
        @(negedge clk);
        addr=8'h08; // Illegal change while global HREADY is low.
        @(negedge clk);
        ready=1; select=0; trans=0;
        repeat(2) @(negedge clk);
        if (violations < 1) $fatal(1,"AHB stalled-control violation escaped");
        $display("AMBA_AHB_NEGATIVE_PASS detected=%0d",violations);
        $finish;
    end
    initial begin #10000; $fatal(1,"AHB negative watchdog"); end
endmodule
