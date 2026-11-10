"""Measured AHB crops selected and checked from pre-edge public pins."""
import sys,re,bisect,json,hashlib,os
from pathlib import Path
R=Path(__file__).resolve().parents[2];D=Path(__file__).resolve().parent;O=D/'waveforms'
sys.path.insert(0,str(R/'tools'));import vcd_to_svg
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 assert not O.exists();O.mkdir()
 result=json.loads((D/'run/results.json').read_text());cap=D/'run/functional/capture.vcd';trace=vcd_to_svg.parse_vcd(cap);assert trace.timescale=='1ps'
 starts=[(n,int(t)) for n,t in re.findall(r'^# AHB_CASE_START name=(\w+) time=(\d+)',(D/'run/functional/2.log').read_text(),re.M)]
 windows={n:(t,starts[i+1][1] if i+1<len(starts) else trace.last_tick) for i,(n,t) in enumerate(starts)}
 def seq(n):return trace.events[trace.signals['ahb_uvm_top.bus.'+n].code]
 def before(n,t):
  v=seq(n);i=bisect.bisect_left([x[0] for x in v],t)-1;return int(v[i][1],2) if i>=0 else None
 manifest=dict(source_revision=result['source_revision'],dut_revision=result['source_lock']['revision'],renderer_sha256=sha(Path(__file__)),shared_renderer_sha256=sha(Path(vcd_to_svg.__file__)),figures=[])
 for case in ('pipeline_WW_different','wait_read_5','error_final_held','reset_write_wait'):
  lo,hi=windows[case];edges=[t for t,v in seq('clk') if v=='1' and lo<t<hi and before('reset_n',t)==1]
  accepts=[t for t in edges if before('ready',t) and before('sel',t) and before('trans',t)>=2]
  if case.startswith('pipeline'):
   a,b=accepts[16:18];c=b+10000
   assert b-a==10000 and before('addr',a)==8 and before('addr',b)==44
   assert before('trans',a)==before('trans',b)==2
   assert before('wdata',b)==0x55aa01fe and before('wdata',c)==0x9ac35678 and before('ready',c)
   start,end=a-15000,c+15000;events=dict(first_address_edge=a,next_address_and_prior_data_edge=b,second_data_edge=c,saved_addresses=[8,44],paired_values=['0x55aa01fe','0x9ac35678'])
   title='Measured full-rate W-W: next address overlaps prior write data'
  elif case=='wait_read_5':
   a,b=accepts[16:18];waits=[t for t in edges if a<t<b and not before('ready',t)]
   assert len(waits)==5 and all(before('readyout',t)==1 and before('addr',t)==44 for t in waits)
   assert len({before('wdata',t) for t in waits})>1
   start,end=a-10000,b+25000;events=dict(read_address_edge=a,global_wait_edges=waits,next_address_and_read_retirement=b,read_value=hex(before('rdata',b)),changing_write_data_during_read=True)
   title='Measured read wait: local ready high, five global stalls, changing HWDATA'
  elif case=='error_final_held':
   low=[t for t in edges if before('resp',t) and not before('readyout',t)]
   held=[t for t in edges if before('resp',t) and before('readyout',t) and not before('ready',t)]
   final=[t for t in edges if before('resp',t) and before('ready',t)]
   assert len(low)==1 and len(held)==5 and len(final)==1
   assert before('trans',low[0])==2 and all(before('trans',t)==0 for t in held+final)
   start,end=low[0]-25000,final[0]+25000;events=dict(first_error_edge=low[0],held_final_error_edges=held,error_retirement=final[0],speculative_address_canceled=True)
   title='Measured ERROR: speculative cancellation and globally held final phase'
  else:
   falls=[t for t,v in seq('reset_n') if v=='0' and lo<t<hi];assert len(falls)==2
   fall=falls[-1];last=next(t for t in reversed(edges) if t<fall)
   assert not before('ready',last) and before('addr',last)==48
   subsequent=[t for t in accepts if t>fall];read_retire=subsequent[0]+10000
   assert before('rdata',read_retire)==0
   start,end=fall-35000,fall+85000;events=dict(asynchronous_reset_tick=fall,preceding_wait_edge=last,unaccepted_next_address=48,first_post_reset_read_retirement=read_retire,observed_zero=0)
   title='Measured reset cancellation: stalled write, speculative address, cleared readback'
  dest=O/(case+'.svg');signals=['clk','reset_n','sel','trans','addr','write','size','wdata','rdata','ext_ready','readyout','ready','resp']
  assert vcd_to_svg.main(['--vcd',str(cap),'--signals',*['ahb_uvm_top.bus.'+n for n in signals],'--start',str(start),'--end',str(end),'--output',str(dest),'--origin','simulator','--title',title+' (original bytes)'])==0
  meta=json.loads(dest.with_suffix('.json').read_text());meta.update(source_relative_path=os.path.relpath(cap,O).replace('\\','/'),source_revision=result['source_revision'],source_representation='original simulator capture; Git -text; no conversion',captured_sha256=sha(cap),selected_public_pin_events=events)
  dest.with_suffix('.json').write_bytes((json.dumps(meta,indent=2)+'\n').encode());manifest['figures'].append(dict(figure=dest.name,metadata=dest.with_suffix('.json').name,**meta))
 (O/'MANIFEST.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
if __name__=='__main__':main()
