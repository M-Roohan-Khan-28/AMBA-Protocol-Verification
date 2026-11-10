module ahb_lite_slave_ram(

    input  logic        HCLK,
    input  logic        HRESETn,
    input  logic        HSEL,
    input  logic [7:0]  HADDR,
    input  logic [1:0]  HTRANS,
    input  logic        HWRITE,
    input  logic [2:0]  HSIZE,
    input  logic [31:0] HWDATA,
    input  logic        HREADY,

    output logic [31:0] HRDATA,
    output logic        HREADYOUT,
    output logic        HRESP

);

logic [31:0] memory [0:15];
logic        transfer_q;
logic        write_q;
logic        error_q;
logic [3:0]  index_q;
typedef enum logic [1:0] {RESP_OK, RESP_ERROR_WAIT, RESP_ERROR_FINISH} response_state_t;
response_state_t response_state;
integer      i;
logic [31:0] bad_address_data;
always @(posedge HCLK) if(HREADY) bad_address_data <= HWDATA;

// An invalid transfer has a two-cycle ERROR response. The first phase inserts
// a local wait; the second completes when global HREADY permits retirement.
assign HREADYOUT = response_state != RESP_ERROR_WAIT;
assign HRESP = response_state != RESP_OK;
assign HRDATA = (transfer_q && !write_q && !error_q) ?
                memory[index_q] : 32'h0000_0000;

always_ff @(posedge HCLK or negedge HRESETn)
begin

    if(!HRESETn)
    begin

        transfer_q <= 1'b0;
        write_q <= 1'b0;
        error_q <= 1'b0;
        index_q <= 4'd0;
        response_state <= RESP_OK;

        for(i = 0; i < 16; i = i + 1)
            memory[i] <= 32'h0000_0000;

    end
    else if(response_state == RESP_ERROR_WAIT)
    begin
        // Advance the locally inserted wait independently of global HREADY.
        response_state <= RESP_ERROR_FINISH;
    end
    else if(HREADY)
    begin

        if(transfer_q && write_q && !error_q)
            memory[index_q] <= bad_address_data;

        transfer_q <= HSEL && HTRANS[1];
        write_q <= HWRITE;
        index_q <= HADDR[5:2];
        error_q <= (HADDR[1:0] != 2'b00) ||
                   (HADDR > 8'h3C) ||
                   (HSIZE != 3'b010);

        if(HSEL && HTRANS[1] && ((HADDR[1:0] != 2'b00) ||
                                  (HADDR > 8'h3C) || (HSIZE != 3'b010)))
            response_state <= RESP_ERROR_WAIT;
        else
            response_state <= RESP_OK;

    end

end

endmodule
