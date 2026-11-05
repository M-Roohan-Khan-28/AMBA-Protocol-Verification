`timescale 1ns/1ps
module apb_monitor_negative;
    logic clk = 0;
    always #5 clk = ~clk;
    logic reset_n=0, select=0, enable=0, write=0, ready=1, error=0;
    logic [7:0] addr=0;
    logic [31:0] wdata=0;
    int transfers, violations;
    apb_monitor mon(.*);
    initial begin
        repeat (2) @(negedge clk);
        reset_n=1;
        // Access without setup must be caught by the same passive checker.
        select=1; enable=1; addr=8'h04;
        @(negedge clk);
        select=0; enable=0;
        repeat (2) @(negedge clk);
        if (violations < 1) $fatal(1, "APB missing-setup violation escaped");
        $display("AMBA_APB_NEGATIVE_PASS detected=%0d", violations);
        $finish;
    end
    initial begin #10000; $fatal(1, "APB negative watchdog"); end
endmodule
