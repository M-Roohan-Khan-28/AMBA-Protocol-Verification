`timescale 1ns/1ps
// DUT adapter for the existing 64-word APB RAM; oracle is a separate array.
module apb_adapter_test;
    logic clk = 0;
    always #5 clk = ~clk;
    apb_if bus(clk);
    apb_ram dut(bus);
    int transfers, violations, checks = 0;
    logic [31:0] oracle [0:63];
    apb_monitor mon(
        .clk(clk), .reset_n(bus.PRESETn), .select(bus.PSEL),
        .enable(bus.PENABLE), .write(bus.PWRITE), .ready(bus.PREADY),
        .error(bus.PSLVERR), .addr(bus.PADDR), .wdata(bus.PWDATA),
        .transfers(transfers), .violations(violations)
    );

    task automatic transfer(input bit wr, input int index, input logic [31:0] value);
        @(negedge clk);
        bus.PSEL = 1; bus.PENABLE = 0; bus.PWRITE = wr;
        bus.PADDR = index * 4; bus.PWDATA = value;
        @(negedge clk);
        bus.PENABLE = 1;
        #1;
        if (!bus.PREADY || bus.PSLVERR) $fatal(1, "Unexpected APB response index=%0d", index);
        if (!wr) begin
            if (bus.PRDATA !== oracle[index])
                $fatal(1, "APB read index=%0d got=%h expected=%h", index, bus.PRDATA, oracle[index]);
            checks++;
        end
        @(negedge clk);
        bus.PSEL = 0; bus.PENABLE = 0;
        if (wr) oracle[index] = value;
        checks++;
    endtask

    initial begin : run
        bus.PRESETn = 0; bus.PSEL = 0; bus.PENABLE = 0;
        bus.PWRITE = 0; bus.PADDR = 0; bus.PWDATA = 0;
        for (int i=0; i<64; i++) oracle[i] = 0;
        repeat (3) @(negedge clk);
        bus.PRESETn = 1;
        for (int i=0; i<64; i++) transfer(0, i, 0);
        for (int i=0; i<64; i++) transfer(1, i, 32'hC3500000 ^ (i * 32'h01010101));
        for (int i=63; i>=0; i--) transfer(0, i, 0);
        repeat (2) @(negedge clk);
        if (violations != 0 || transfers != 192)
            $fatal(1, "APB pre-reset monitor transfers=%0d violations=%0d", transfers, violations);
        checks += 2;
        bus.PRESETn = 0;
        for (int i=0; i<64; i++) oracle[i] = 0;
        repeat (2) @(negedge clk);
        bus.PRESETn = 1;
        for (int i=0; i<64; i++) transfer(0, i, 0);
        repeat (2) @(negedge clk);
        if (violations != 0 || transfers != 64)
            $fatal(1, "APB post-reset monitor transfers=%0d violations=%0d expected=64/0", transfers, violations);
        checks += 2;
        $display("AMBA_APB_PASS transfers=256 checks=%0d violations=%0d", checks, violations);
        $finish;
    end
    initial begin #100000; $fatal(1, "APB watchdog"); end
endmodule
