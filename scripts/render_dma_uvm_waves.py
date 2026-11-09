#!/usr/bin/env python3
"""Render measured DMA public-pin events from a full passing locked run."""
import argparse,bisect,hashlib,json,os,re,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'tools'))
import vcd_to_svg

def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--run',type=Path,required=True);ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args();r=json.loads((a.run/'results.json').read_text())
    if a.output.exists() or not r['milestone_pass']:ap.error('Require full passing run and fresh figure directory')
    a.output.mkdir(parents=True)
    capture=a.run/'functional/capture.vcd';trace=vcd_to_svg.parse_vcd(capture)
    assert trace.timescale=='1ps'
    starts=[(n,int(t)) for n,t in re.findall(r'^# DMA_CASE_START name=(\w+) time=(\d+)',(a.run/'functional/2.log').read_text(),re.M)]
    windows={n:(t,starts[i+1][1] if i+1<len(starts) else trace.last_tick) for i,(n,t) in enumerate(starts)}
    def seq(n):return trace.events[trace.signals['dma_uvm_top.bus.'+n].code]
    def before(n,t):
        values=seq(n);i=bisect.bisect_left([x[0] for x in values],t)-1
        return values[i][1] if i>=0 else 'x'
    edges=[t for t,v in seq('clk') if v=='1' and before('reset_n',t)=='1']
    def hs(n,t):return before(n+'valid',t)=='1' and before(n+'ready',t)=='1'
    def case_edges(n):
        lo,hi=windows[n];return [t for t in edges if lo<=t<hi]
    write=['clk','reset_n','d_awvalid','d_awready','d_awaddr','d_awlen','d_wvalid','d_wready','d_wstrb','d_wlast','d_bvalid','d_bready','d_bresp']
    crops=[]
    for case in ('aw_first','w_first','all_w_before_aw_16','same_edge_aw_w_2'):
        ee=case_edges(case);aw=next(t for t in ee if hs('d_aw',t));ww=[t for t in ee if hs('d_w',t)]
        if case=='aw_first':assert aw<ww[0]
        if case=='w_first':assert ww[0]<aw
        if case=='all_w_before_aw_16':assert len(ww)==16 and ww[-1]<aw
        if case=='same_edge_aw_w_2':assert aw==ww[0]
        end=next(t for t in ee if hs('d_b',t))
        crops.append((case,min(aw,ww[0])-20000,end+20000,write,dict(first_aw=aw,first_w=ww[0],last_w=ww[15] if case.endswith('_16') else None)))
    case='destination_page_split';ee=case_edges(case);aws=[t for t in ee if hs('d_aw',t)]
    assert len(aws)>1
    tail=next(t for t in ee if hs('d_w',t) and int(before('d_wstrb',t),2)!=255)
    crops.append((case,aws[0]-20000,tail+60000,write,dict(aw_edges=aws,
      aw_addresses=[hex(int(before('d_awaddr',t),2)) for t in aws],
      aw_lengths=[int(before('d_awlen',t),2)+1 for t in aws],tail_edge=tail,tail_strobe=hex(int(before('d_wstrb',tail),2)))))
    case='read_error_middle';ee=case_edges(case);err=next(t for t in ee if hs('d_r',t) and int(before('d_rresp',t),2)==2)
    crops.append((case,err-50000,err+65000,['clk','reset_n','d_arvalid','d_arready','d_araddr','d_arlen','d_rvalid','d_rready','d_rresp','d_rlast','irq'],dict(error_edge=err)))
    for case in ('reset_commit_before_b','reset_control_aw_only'):
        lo,hi=windows[case];resets=[t for t,v in seq('reset_n') if lo<t<hi and v=='0'];tick=resets[-1]
        signals=write+['irq'] if case=='reset_commit_before_b' else ['clk','reset_n','c_awvalid','c_awready','c_awaddr','c_wvalid','c_wready','c_bvalid','c_bready','c_arvalid','c_arready','c_rvalid','c_rready','c_rdata']
        if case=='reset_commit_before_b':
            ee=case_edges(case);lastw=max(t for t in ee if t<tick and hs('d_w',t));assert before('d_bvalid',tick)=='0'
            start=lastw-50000
        else:start=tick-50000
        crops.append((case,start,tick+130000,signals,dict(reset_assertion=tick)))
    manifest=dict(source_revision=r['source_revision'],dut_revision=r['source_lock']['revision'],
      renderer_sha256=sha(Path(__file__)),shared_renderer_sha256=sha(Path(vcd_to_svg.__file__)),
      byte_policy='Exact original simulator capture; Git -text; no newline transformation',figures=[])
    for name,start,end,signals,events in crops:
        dest=a.output/(name+'.svg')
        title='Measured DMA: '+name.replace('_',' ')
        if name=='destination_page_split':title='Measured DMA: AW '+ ' -> '.join(events['aw_addresses'])+'; tail WSTRB='+events['tail_strobe']
        assert vcd_to_svg.main(['--vcd',str(capture),'--signals',*['dma_uvm_top.bus.'+n for n in signals],
          '--start',str(start),'--end',str(end),'--output',str(dest),'--origin','simulator',
          '--title',title+' (original capture bytes)'])==0
        meta=json.loads(dest.with_suffix('.json').read_text())
        meta.update(source_relative_path=os.path.relpath(capture,a.output).replace('\\','/'),source_revision=r['source_revision'],
          source_representation='original simulator capture bytes; committed without conversion',captured_sha256=sha(capture),
          source_crlf_count=capture.read_bytes().count(b'\r\n'),selected_public_pin_events=events)
        dest.with_suffix('.json').write_bytes((json.dumps(meta,indent=2)+'\n').encode())
        manifest['figures'].append(dict(figure=dest.name,metadata=dest.with_suffix('.json').name,**meta))
    (a.output/'MANIFEST.json').write_bytes((json.dumps(manifest,indent=2)+'\n').encode())
    return 0
if __name__=='__main__':raise SystemExit(main())
