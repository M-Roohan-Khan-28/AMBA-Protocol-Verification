`timescale 1ns/1ps
module ahb_sva_control;
  logic clk=0;always #5 clk=~clk;
  ahb_bus b(clk);ahb_assertions checker_i(b);
  string scenario,expected="";
  task automatic tick(input bit sel=0,input bit[1:0] trans=0,input bit wr=0,
    input bit[7:0] addr=0,input bit[31:0] data=0,input bit global_ready=1,
    input bit local_ready=1,input bit response=0,input bit reset=1,input bit[2:0] size=2);
    @(negedge clk);b.sel=sel;b.trans=trans;b.write=wr;b.addr=addr;b.wdata=data;
    b.ready=global_ready;b.readyout=local_ready;b.resp=response;b.reset_n=reset;b.size=size;
    @(posedge clk);#2;
  endtask
  initial begin
    b.rdata=0;b.ready=1;b.readyout=1;b.resp=0;
    if(!$value$plusargs("SCENARIO=%s",scenario))$fatal(1,"missing scenario");
    void'($value$plusargs("EXPECT_SVA=%s",expected));
    tick(0,0,0,0,0,1,1,0,0);tick();
    case(scenario)
      "address_hold","direction_hold","size_hold","selection_hold","active_to_idle":begin
        tick(1,2,0,0,0,0);
        case(scenario)
          "address_hold":tick(1,2,0,4,0,1);
          "direction_hold":tick(1,2,1,0,0,1);
          "size_hold":tick(1,2,0,0,0,1,1,0,1,1);
          "selection_hold":tick(0,2,0,0,0,1);
          default:tick();
        endcase
      end
      "write_data":begin tick(1,2,1);tick(0,0,0,0,32'h1234,0);tick(0,0,0,0,32'h1235);end
      "idle_to_seq":begin tick(0,0,0,0,0,0);tick(1,3);end
      "busy_control":begin tick(1,2,0,0);tick(1,1,0,4,0,0);tick(1,3,1,4);end
      "response_owner":tick(0,0,0,0,0,0,0,1);
      "short_error":begin tick(1,2);tick(0,0,0,0,0,1,1,1);end
      "long_error":begin tick(1,2);tick(0,0,0,0,0,0,0,1);tick(0,0,0,0,0,0,0,1);end
      "held_error_lost":begin tick(1,2);tick(0,0,0,0,0,0,0,1);tick(0,0,0,0,0,0,1,1);tick();end
      "local_ok_wait":tick(0,0,0,0,0,0,0,0);
      "global_through_error":begin tick(1,2);tick(0,0,0,0,0,1,0,1);end
      "reset_output":begin @(negedge clk);b.reset_n=0;b.rdata=1;@(posedge clk);#2;end
      "legal_read_wdata":begin tick(1,2);tick(0,0,0,0,32'h1111,0);tick(0,0,0,4,32'h2222,0);tick(0,0,0,8,32'h3333);end
      "legal_idle_change":begin tick(0,0,0,4,0,0);tick(0,0,1,8,1,0);tick(1,2,0,12,2,0);tick(1,2,0,12,3);end
      "legal_busy_seq":begin tick(1,2,0,0);tick(1,1,0,4,0,0);tick(1,3,0,4,1,0);tick(1,3,0,4,2);end
      "legal_busy_nonseq":begin tick(1,2,0,0);tick(1,1,0,4,0,0);tick(1,2,1,8,1,0);tick(1,2,1,8,2);end
      "legal_busy_idle":begin tick(1,2,0,0);tick(1,1,0,4,0,0);tick(0,0,0,8,1,0);tick();end
      "legal_error_cancel":begin tick(1,2,1,1);tick(1,2,0,4,32'h55,0,0,1);tick(0,0,0,12,32'h55,0,1,1);tick(0,0,0,20,32'h55,1,1,1);end
      "legal_error_continue":begin tick(1,2,0,1);tick(1,2,0,4,0,0,0,1);tick(1,2,0,4,0,1,1,1);end
      "legal_reset_cancel":begin tick(1,2,1);tick(1,2,0,4,32'h55,0);tick(0,0,0,0,0,1,1,0,0);tick(1,2,1,8,1);tick(0,0,0,0,32'h7788);end
      default:$fatal(1,"unknown scenario %s",scenario);
    endcase
    if(b.sva_count!=(expected!=""))$fatal(1,"wrong detection count %0d",b.sva_count);
    $display("AHB_SVA_CONTROL_PASS name=%s detections=%0d",scenario,b.sva_count);$finish;
  end
  initial begin #10000;$fatal(1,"AHB_SVA_TIMEOUT");end
endmodule
