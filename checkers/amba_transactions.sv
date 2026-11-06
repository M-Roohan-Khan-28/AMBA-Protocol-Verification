package amba_transactions;
    typedef struct packed {
        logic write;
        logic [7:0] addr;
        logic [31:0] data;
    } apb_transaction_t;
    typedef struct packed {
        logic error;
        logic [31:0] data;
    } apb_result_t;
    typedef struct packed {
        logic write;
        logic [7:0] addr;
        logic [2:0] size;
        logic [31:0] data;
    } ahb_transaction_t;
    typedef struct packed {
        logic error;
        logic [31:0] data;
    } ahb_result_t;
    typedef struct packed {
        logic write;
        logic [31:0] addr;
        logic [31:0] data;
        logic [3:0] strb;
    } axi_lite_transaction_t;
    typedef struct packed {
        logic error;
        logic [31:0] data;
    } axi_lite_result_t;
endpackage
