`timescale 1ns/1ps
module axi_lite_adapter_test;
    import amba_transactions::*;
    localparam logic [31:0] BASE=32'h20000000;
    logic clk=0, reset_n=0;
    always #5 clk=~clk;
    logic req_valid,req_write;
    logic [31:0] req_addr,req_wdata;
    logic [3:0] req_wstrb;
    logic req_ready,response_valid,response_error;
    logic [31:0] response_data;
    logic [31:0] oracle[0:7];
    int checks=0;
    int aw_count,w_count,b_count,ar_count,r_count,violations;
    axi4_lite_memory_top #(.BASE_ADDR(BASE),.SRAM_DEPTH(8)) dut(.*);
    axi_lite_request_driver driver(.*);
    axi_lite_monitor mon(
        .clk(clk),.reset_n(reset_n),
        .awvalid(dut.bus.awvalid),.awready(dut.bus.awready),.awaddr(dut.bus.awaddr),
        .wvalid(dut.bus.wvalid),.wready(dut.bus.wready),.wdata(dut.bus.wdata),.wstrb(dut.bus.wstrb),
        .bvalid(dut.bus.bvalid),.bready(dut.bus.bready),.bresp(dut.bus.bresp),
        .arvalid(dut.bus.arvalid),.arready(dut.bus.arready),.araddr(dut.bus.araddr),
        .rvalid(dut.bus.rvalid),.rready(dut.bus.rready),.rdata(dut.bus.rdata),.rresp(dut.bus.rresp),
        .aw_count(aw_count),.w_count(w_count),.b_count(b_count),
        .ar_count(ar_count),.r_count(r_count),.violations(violations)
    );
    task automatic transact(input bit wr,input logic[31:0] addr,
                            input logic[31:0] data,input logic[3:0] strb,
                            input bit expected_error,input logic[31:0] expected_data);
        axi_lite_transaction_t tx;
        axi_lite_result_t result;
        tx.write=wr;tx.addr=addr;tx.data=data;tx.strb=strb;
        driver.issue(tx,result);
        if(result.error !== expected_error)
            $fatal(1,"AXIL response addr=%h got=%b expected=%b",addr,result.error,expected_error);
        checks++;
        if(!wr && !expected_error) begin
            if(result.data !== expected_data)
                $fatal(1,"AXIL read addr=%h got=%h expected=%h",addr,result.data,expected_data);
            checks++;
        end
    endtask
    task automatic wr(input int index,input logic[31:0] data,input logic[3:0] strb);
        transact(1,BASE+index*4,data,strb,0,0);
        for(int lane=0;lane<4;lane++) if(strb[lane])
            oracle[index][lane*8+:8]=data[lane*8+:8];
    endtask
    task automatic rd(input int index);
        transact(0,BASE+index*4,0,0,0,oracle[index]);
    endtask
    initial begin
        repeat(3) @(negedge clk); reset_n=1;
        for(int i=0;i<8;i++) begin
            oracle[i]=0;
            wr(i,32'h10305070 ^ (i*32'h01010101),4'hf);
            rd(i);
        end
        for(int s=0;s<16;s++) begin wr(2,32'hA1B2C300+s,4'(s)); rd(2); end
        transact(1,BASE-4,32'hffffffff,4'hf,1,0);
        transact(1,BASE+32,32'hffffffff,4'hf,1,0);
        transact(0,BASE-4,0,0,1,0);
        transact(0,BASE+1,0,0,1,0);
        for(int i=0;i<8;i++) rd(i);
        repeat(2) @(negedge clk);
        if(violations!=0 || aw_count!=26 || w_count!=26 || b_count!=26 ||
           ar_count!=34 || r_count!=34)
            $fatal(1,"AXIL monitor AW/W/B=%0d/%0d/%0d AR/R=%0d/%0d violations=%0d",
                   aw_count,w_count,b_count,ar_count,r_count,violations);
        checks+=6;
        $display("AMBA_AXIL_PASS writes=26 reads=34 checks=%0d violations=%0d",checks,violations);
        $finish;
    end
    initial begin #200000; $fatal(1,"AXIL watchdog"); end
endmodule
