`timescale 1ns/1ps
interface probe_bus;
  logic [7:0] request, response;
  modport device(input request, output response);
endinterface
module probe_interface_dut(probe_bus.device bus);
  assign bus.response = bus.request ^ 8'ha5;
endmodule
module probe_interfaces;
  probe_bus bus();
  probe_interface_dut dut(bus);
  initial begin
    bus.request=8'h3c; #1;
    if (bus.response !== 8'h99) $fatal(1,"interface/modport probe failed");
    $display("FEATURE_PASS_interfaces"); $finish;
  end
endmodule
