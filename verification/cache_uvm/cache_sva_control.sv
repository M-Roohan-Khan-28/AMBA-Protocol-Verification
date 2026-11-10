`timescale 1ns/1ps
module cache_sva_control;
  cache_bus bus();cache_assertions assertions(bus);
  string scenario;int expected_count;
  task automatic drive(bit c,bit r,bit w,bit way,int idx,int tag,int data,logic hit,logic[7:0] out);
    bus.pins={c,r,w,way,2'(idx),3'(tag),8'(data)};bus.hit=hit;bus.data_out=out;#5;
  endtask
  initial begin
    bus.hit=0;bus.data_out=0;
    if(!$value$plusargs("SCENARIO=%s",scenario))$fatal(1,"Missing scenario");
    #5;drive(0,1,0,0,0,0,0,scenario=="reset",0);
    drive(0,0,0,0,0,0,0,0,scenario=="miss"?8'h55:0);
    drive(0,0,1,0,0,1,8'hA5,0,0);
    drive(1,0,1,0,0,1,8'hA5,1,scenario=="write"?8'h5A:8'hA5);
    drive(0,0,0,0,0,1,8'hA5,1,8'hA5);
    drive(0,0,0,1,0,1,8'h13,scenario=="hit"?0:1,scenario=="stored"?8'h5A:8'hA5);
    drive(0,0,1,1,0,1,8'h3C,1,8'hA5);
    drive(1,0,1,1,0,1,8'h3C,1,8'hA5);
    drive(0,0,0,1,0,1,8'h3C,1,scenario=="duplicate"?8'h3C:8'hA5);
    // No write: both ignored inputs may change freely, with lookup preserved.
    drive(0,0,0,0,0,1,8'hFF,1,8'hA5);
    drive(1,0,0,1,0,1,8'h00,1,8'hA5);
    drive(0,1,1,1,0,1,8'hF0,0,0);
    drive(1,1,1,1,0,1,8'hF0,0,0);
    drive(0,0,0,0,0,1,8'h00,0,0);
    expected_count=(scenario=="legal")?0:1;
    if(bus.sva_count!=expected_count)$fatal(1,"Wrong detections %0d",bus.sva_count);
    $display("CACHE_SVA_CONTROL_PASS name=%s detections=%0d",scenario,bus.sva_count);$finish;
  end
  initial begin #1000;$fatal(1,"CACHE_PROGRESS_TIMEOUT");end
endmodule
