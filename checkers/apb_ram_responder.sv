`timescale 1ns/1ps
// Configurable APB responder for driver/checker tests, separate from DUT RTL.
module apb_ram_responder #(
    parameter int WAIT_CYCLES=2,
    parameter int WORDS=4,
    parameter int ERROR_INDEX=3
) (
    input logic clk, reset_n, select, enable, write,
    input logic [7:0] addr,
    input logic [31:0] wdata,
    output logic ready, error,
    output logic [31:0] rdata
);
    logic [31:0] mem[0:WORDS-1];
    int wait_count;
    wire valid_index=(int'(addr[7:2])<WORDS);
    assign ready=select&&enable&&(wait_count>=WAIT_CYCLES);
    assign error=ready&&(!valid_index || int'(addr[7:2])==ERROR_INDEX);
    assign rdata=(select&&!write&&valid_index&&!error) ? mem[addr[7:2]] : 32'b0;
    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            wait_count<=0;
            for(int i=0;i<WORDS;i++) mem[i]<=0;
        end else if(!select || !enable) wait_count<=0;
        else if(!ready) wait_count<=wait_count+1;
        else begin
            if(write&&!error) mem[addr[7:2]]<=wdata;
            wait_count<=0;
        end
    end
endmodule
