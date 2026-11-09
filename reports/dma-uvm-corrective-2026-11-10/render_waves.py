"""Generate measured corrective crops using pre-edge public-pin values."""
import sys,re,bisect,json,hashlib,os
from pathlib import Path
R=Path(__file__).resolve().parents[2] if __file__.replace('\\','/').find('/reports/')>=0 else Path('C:/short/dma-fix-20261110')
sys.path.insert(0,str(R/'tools'));import vcd_to_svg
D=R/'reports/dma-uvm-corrective-2026-11-10';O=D/'waveforms'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 assert not O.exists();O.mkdir()
 result=json.loads((D/'run/results.json').read_text());manifest=dict(source_revision=result['source_revision'],dut_revision=result['source_lock']['revision'],renderer_sha256=sha(Path(__file__)),shared_renderer_sha256=sha(Path(vcd_to_svg.__file__)),figures=[])
 for group,case in [('inactive-lanes','inactive_tail_1'),('inactive-lanes','inactive_tail_7'),('functional','busy_rejections')]:
  capture=D/'run'/group/'capture.vcd';trace=vcd_to_svg.parse_vcd(capture);assert trace.timescale=='1ps'
  starts=[(n,int(t)) for n,t in re.findall(r'^# DMA_CASE_START name=(\w+) time=(\d+)',(D/'run'/group/'2.log').read_text(),re.M)]
  windows={n:(t,starts[i+1][1] if i+1<len(starts) else trace.last_tick) for i,(n,t) in enumerate(starts)}
  def seq(n):return trace.events[trace.signals['dma_uvm_top.bus.'+n].code]
  def before(n,t):
   values=seq(n);i=bisect.bisect_left([x[0] for x in values],t)-1;return values[i][1] if i>=0 else 'x'
  lo,hi=windows[case];edges=[t for t,v in seq('clk') if v=='1' and lo<=t<hi and before('reset_n',t)=='1']
  def hs(n,t):return before(n+'valid',t)=='1' and before(n+'ready',t)=='1'
  if group=='inactive-lanes':
   tail=next(t for t in edges if hs('d_w',t) and int(before('d_wstrb',t),2)!=255)
   stalls=[t for t in edges if t<tail and before('d_wvalid',t)=='1' and before('d_wready',t)=='0' and int(before('d_wstrb',t),2)!=255]
   assert len(stalls)>=3
   assert len({before('d_wdata',t) for t in [*stalls,tail]})==1
   start=stalls[0]-15000;end=tail+45000
   signals=['clk','reset_n','d_awvalid','d_awready','d_awaddr','d_wvalid','d_wready','d_wdata','d_wstrb','d_wlast','d_bvalid','d_bready']
   events=dict(partial_stall_edges=stalls,tail_acceptance=tail,wdata=hex(int(before('d_wdata',tail),2)),strobe=hex(int(before('d_wstrb',tail),2)))
   title=f'Measured legal inactive-lane transform: tail {case[-1]}, stable during {len(stalls)} stalled edges'
  else:
   rejected=next(t for t in edges if hs('c_b',t) and int(before('c_bresp',t),2)==2)
   reads=[t for t in edges if t>rejected and hs('c_ar',t)][:6]
   assert [int(before('c_araddr',t),2) for t in reads]==[0,4,8,16,20,12]
   responses=[t for t in edges if t>reads[0] and hs('c_r',t)][:6]
   assert [int(before('c_rdata',t),2) for t in responses]==[0x1080,0x8000,128,1,0,0]
   assert all(before('d_rvalid',t)=='0' for t in edges if rejected<=t<=responses[-1])
   start=rejected-50000;end=responses[-1]+15000
   signals=['clk','c_awvalid','c_awready','c_awaddr','c_wvalid','c_wready','c_wdata','c_bvalid','c_bready','c_bresp','c_arvalid','c_arready','c_araddr','c_rvalid','c_rready','c_rdata','d_rvalid','irq']
   events=dict(rejected_b=rejected,read_address_edges=reads,read_response_edges=responses,protected_values=['0x1080','0x8000','128','busy=1','error=0','control=0'],responder_paused=True)
   title='Measured busy rejection: SLVERR, unchanged CSR reads while memory responder is paused'
  dest=O/(case+'.svg')
  assert vcd_to_svg.main(['--vcd',str(capture),'--signals',*['dma_uvm_top.bus.'+n for n in signals],'--start',str(start),'--end',str(end),'--output',str(dest),'--origin','simulator','--title',title+' (original bytes)'])==0
  meta=json.loads(dest.with_suffix('.json').read_text());meta.update(source_relative_path=os.path.relpath(capture,O).replace('\\','/'),source_revision=result['source_revision'],source_representation='original simulator capture; Git -text; no conversion',captured_sha256=sha(capture),selected_public_pin_events=events)
  dest.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
  manifest['figures'].append(dict(figure=dest.name,metadata=dest.with_suffix('.json').name,**meta))
 (O/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
if __name__=='__main__':main()
