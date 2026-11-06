`timescale 1ns/1ps
// DUT adapter for the existing 64-word APB RAM; oracle is a separate array.
module apb_adapter_test;
    import amba_transactions::*;
    logic clk = 0;
    always #5 clk = ~clk;
    apb_if bus(clk);
    apb_ram dut(bus);
    apb_master_driver driver(
        .clk(clk),.ready(bus.PREADY),.error(bus.PSLVERR),.rdata(bus.PRDATA),
        .reset_n(bus.PRESETn),.select(bus.PSEL),.enable(bus.PENABLE),
        .write(bus.PWRITE),.addr(bus.PADDR),.wdata(bus.PWDATA)
    );
    int transfers, violations, checks = 0;
    logic [31:0] oracle [0:63];
    apb_monitor mon(
        .clk(clk), .reset_n(bus.PRESETn), .select(bus.PSEL),
        .enable(bus.PENABLE), .write(bus.PWRITE), .ready(bus.PREADY),
        .error(bus.PSLVERR), .addr(bus.PADDR), .wdata(bus.PWDATA),
        .transfers(transfers), .violations(violations)
    );

    task automatic transfer(input bit wr, input int index, input logic [31:0] value);
        apb_transaction_t tx;
        apb_result_t result;
        tx.write=wr;tx.addr=index*4;tx.data=value;
        driver.issue(tx,result);
        if (result.error) $fatal(1, "Unexpected APB response index=%0d", index);
        if (!wr) begin
            if (result.data !== oracle[index])
                $fatal(1, "APB read index=%0d got=%h expected=%h", index, result.data, oracle[index]);
            checks++;
        end
        if (wr) oracle[index] = value;
        checks++;
    endtask

    initial begin : run
        for (int i=0; i<64; i++) oracle[i] = 0;
        driver.reset_bus(3);
        for (int i=0; i<64; i++) transfer(0, i, 0);
        for (int i=0; i<64; i++) transfer(1, i, 32'hC3500000 ^ (i * 32'h01010101));
        for (int i=63; i>=0; i--) transfer(0, i, 0);
        repeat (2) @(negedge clk);
        if (violations != 0 || transfers != 192)
            $fatal(1, "APB pre-reset monitor transfers=%0d violations=%0d", transfers, violations);
        checks += 2;
        for (int i=0; i<64; i++) oracle[i] = 0;
        driver.reset_bus(2);
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
