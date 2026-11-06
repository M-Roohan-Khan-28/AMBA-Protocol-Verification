`timescale 1ns/1ps
module ahb_adapter_test;
    import amba_transactions::*;
    logic HCLK=0;
    always #5 HCLK=~HCLK;
    logic HRESETn=0, HSEL, HWRITE, HREADY=1;
    logic [7:0] HADDR;
    logic [1:0] HTRANS;
    logic [2:0] HSIZE;
    logic [31:0] HWDATA;
    logic [31:0] HRDATA;
    logic HREADYOUT, HRESP;
    int addresses, violations, checks=0;
    logic [31:0] oracle[0:15];
    ahb_lite_slave_ram dut(.*);
    ahb_lite_master_driver driver(
        .clk(HCLK),.readyout(HREADYOUT),.resp(HRESP),.rdata(HRDATA),
        .select(HSEL),.write(HWRITE),.addr(HADDR),.trans(HTRANS),
        .size(HSIZE),.wdata(HWDATA)
    );
    ahb_lite_monitor mon(
        .clk(HCLK), .reset_n(HRESETn), .select(HSEL), .ready(HREADY),
        .readyout(HREADYOUT), .resp(HRESP), .addr(HADDR), .trans(HTRANS),
        .write(HWRITE), .size(HSIZE), .addresses(addresses),
        .violations(violations)
    );

    task automatic xfer(input bit wr, input logic [7:0] address,
                        input logic [2:0] sz, input logic [31:0] data,
                        input bit expect_err);
        ahb_transaction_t tx;
        ahb_result_t result;
        tx.write=wr;tx.addr=address;tx.size=sz;tx.data=data;
        driver.issue(tx,result);
        if (result.error !== expect_err)
            $fatal(1,"AHB response addr=%h got=%b expected=%b",address,result.error,expect_err);
        checks++;
        if (!wr) begin
            if (result.data !== (expect_err ? 32'b0 : oracle[address[5:2]]))
                $fatal(1,"AHB read addr=%h got=%h expected=%h",address,result.data,
                       expect_err ? 32'b0 : oracle[address[5:2]]);
            checks++;
        end
        if (wr && !expect_err) oracle[address[5:2]]=data;
    endtask

    initial begin
        for(int i=0;i<16;i++) oracle[i]=0;
        repeat(3) @(negedge HCLK);
        HRESETn=1;
        for(int i=0;i<16;i++) xfer(0, i*4, 2, 0, 0);
        for(int i=0;i<16;i++) xfer(1, i*4, 2, 32'hA5A50000+i*32'h01020305, 0);
        for(int i=15;i>=0;i--) xfer(0, i*4, 2, 0, 0);
        xfer(1, 8'h02, 2, 32'hDEADBEEF, 1);
        xfer(0, 8'h40, 2, 0, 1);
        xfer(0, 8'h00, 0, 0, 1);
        for(int i=0;i<16;i++) xfer(0, i*4, 2, 0, 0);
        repeat(2) @(negedge HCLK);
        if (violations != 0 || addresses != 67)
            $fatal(1,"AHB monitor addresses=%0d violations=%0d",addresses,violations);
        checks+=2;
        $display("AMBA_AHB_PASS addresses=%0d checks=%0d violations=%0d",addresses,checks,violations);
        $finish;
    end
    initial begin #100000; $fatal(1,"AHB watchdog"); end
endmodule
