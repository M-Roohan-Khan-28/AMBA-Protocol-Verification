typedef longint unsigned addr_t;
function automatic byte unsigned initial_byte(addr_t address);
  bit[31:0] x;
  x=address[31:0]^32'h28a6beef;x=(x^(x>>16))*32'h7feb352d;
  x=(x^(x>>15))*32'h846ca68b;return (x^(x>>16))&255;
endfunction
class dma_command extends uvm_sequence_item;
  `uvm_object_utils(dma_command)
  string label;bit[31:0] src,dst,length;
  int order=4,csr_order=0,expected_error=0,read_error_burst=-1,read_error_beat=-1,write_error_burst=-1;
  int commit_error=1,reset_kind=0,malformed=0,csr_tests=0,chain=0;
  function new(string n="dma_command");super.new(n);endfunction
endclass
class dma_config extends uvm_object;
  `uvm_object_utils(dma_config)
  virtual dma_bus vif;dma_command scenario;
  int epoch=0,read_beats=0,write_commits=0,b_accepts=0;
  bit freeze_data=0;string fault="none";
  function new(string n="dma_config");super.new(n);endfunction
endclass
