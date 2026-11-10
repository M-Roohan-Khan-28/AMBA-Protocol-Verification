`timescale 1ns/1ps
// Bounded public-pin temporal model: no hierarchical DUT reads. Storage
// preservation is observable only when an entry is subsequently looked up.
module cache_assertions(cache_bus b);
  bit valid[2][4];bit[2:0] tags[2][4];bit[7:0] bytes[2][4];
  bit old_clk=0,old_reset=0,commit,check_tick=0,eh,dup;
  bit[7:0] ed;
  string expected="";
  initial void'($value$plusargs("EXPECT_SVA=%s",expected));
  task automatic violation(string id);
    b.sva_count++;$display("CACHE_SVA_DETECTED %s time=%0t",id,$time);
    if(id!=expected)$fatal(1,"CACHE_SVA_UNEXPECTED %s",id);
  endtask
  always @(b.pins) begin
    // Aliased input wires settle before the edge decision. Stimulus intervals
    // are >=5ns; outputs are observed 2ns later, after DUT NBA/combinational work.
    #0;
    commit=!old_clk&&b.clk&&b.write&&!b.reset;
    if((!old_reset&&b.reset)||(!old_clk&&b.clk&&b.reset))begin
      foreach(valid[w,s])begin valid[w][s]=0;tags[w][s]=0;bytes[w][s]=0;end
    end else if(commit)begin valid[b.way_select][b.index]=1;tags[b.way_select][b.index]=b.tag;bytes[b.way_select][b.index]=b.data_in;end
    old_clk=b.clk;old_reset=b.reset;
    eh=0;ed=0;dup=valid[0][b.index]&&valid[1][b.index]&&tags[0][b.index]==b.tag&&tags[1][b.index]==b.tag;
    for(int w=1;w>=0;w--)if(valid[w][b.index]&&tags[w][b.index]==b.tag)begin eh=1;ed=bytes[w][b.index];end
    #2;check_tick=1;#1;check_tick=0;
  end
  a_known:assert property(@(posedge check_tick) !$isunknown({b.hit,b.data_out}))else violation("OUTPUT_KNOWN");
  a_reset:assert property(@(posedge check_tick) b.reset |-> !b.hit&&b.data_out==0)else violation("RESET_DOMINANCE");
  a_write:assert property(@(posedge check_tick) !b.reset&&commit |-> b.hit==eh&&b.data_out==ed)else violation("SELECTED_WRITE");
  a_hit:assert property(@(posedge check_tick) !b.reset&&!commit&&eh |-> b.hit)else violation("LOOKUP_HIT");
  a_miss:assert property(@(posedge check_tick) !b.reset&&!commit&&!eh |-> !b.hit&&b.data_out==0)else violation("MISS_ZERO");
  a_duplicate:assert property(@(posedge check_tick) !b.reset&&!commit&&dup&&b.hit |-> b.data_out==ed)else violation("DUPLICATE_PRIORITY");
  a_preserve:assert property(@(posedge check_tick) !b.reset&&!commit&&eh&&!dup&&b.hit |-> b.data_out==ed)else violation("STORED_ENTRY");
endmodule
