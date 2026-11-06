`timescale 1ns/1ps
module apb_responder_test;
    import amba_transactions::*;
    logic clk=0,reset_n,select,enable,write,ready,error;
    always #5 clk=~clk;
    logic [7:0] addr;
    logic [31:0] wdata,rdata;
    int transfers,violations,wait_edges=0,checks=0;
    logic [31:0] oracle[0:2];
    apb_master_driver driver(.*);
    apb_ram_responder #(.WAIT_CYCLES(2),.WORDS(4),.ERROR_INDEX(3)) responder(.*);
    apb_monitor mon(.*,.transfers(transfers),.violations(violations));
    always @(posedge clk) if(reset_n&&select&&enable&&!ready) wait_edges++;
    task automatic issue(input bit wr,input int index,input logic[31:0] data,
                         input bit expected_error);
        apb_transaction_t tx;
        apb_result_t result;
        tx.write=wr;tx.addr=index*4;tx.data=data;
        driver.issue(tx,result);
        if(result.error!==expected_error)
            $fatal(1,"Responder error index=%0d got=%b expected=%b",index,result.error,expected_error);
        checks++;
        if(!wr&&!expected_error) begin
            if(result.data!==oracle[index])
                $fatal(1,"Responder read index=%0d got=%h expected=%h",index,result.data,oracle[index]);
            checks++;
        end
        if(wr&&!expected_error) oracle[index]=data;
    endtask
    initial begin
        for(int i=0;i<3;i++) oracle[i]=0;
        driver.reset_bus(3);
        for(int i=0;i<3;i++) issue(1,i,32'hA0B0C000+i,0);
        for(int i=0;i<3;i++) issue(0,i,0,0);
        issue(0,3,0,1);
        repeat(2) @(negedge clk);
        if(transfers!=7||violations!=0||wait_edges<14)
            $fatal(1,"Responder monitor transfers=%0d violations=%0d waits=%0d",
                   transfers,violations,wait_edges);
        checks+=3;
        $display("AMBA_APB_RESPONDER_PASS transfers=%0d checks=%0d waits=%0d",transfers,checks,wait_edges);
        $finish;
    end
    initial begin #20000;$fatal(1,"APB responder watchdog");end
endmodule
