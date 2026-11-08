#!/usr/bin/env python3
"""Select actual captured events. Never synthesize expected waveform samples."""
import argparse
import bisect
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'tools'))
import vcd_to_svg

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--run',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args()
    r=json.loads((a.run/'results.json').read_text())
    if a.output.exists() or not r['milestone_pass'] or r['fault_control']:ap.error('Need full passing non-fault run and fresh output')
    a.output.mkdir(parents=True)
    root=Path(__file__).resolve().parent.parent
    revision=subprocess.check_output(['git','-C',str(root),'log','-1','--format=%H','--','scripts/render_axil_uvm_waves.py'],text=True).strip()
    manifest=dict(source_revision=r['source_revision'],renderer_revision=revision,renderer_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
                  policy='Exact simulator capture bytes; scoped Git -text; no newline conversion',figures=[])
    for adapter in [0,1,2]:
        path=a.run/f'adapter-{adapter}/capture.vcd';trace=vcd_to_svg.parse_vcd(path)
        if trace.timescale!='1ps':raise ValueError('Expected 1ps timebase')
        def seq(n):return trace.events[trace.signals['axil_uvm_top.bus.'+n].code]
        def before(n,t):
            values=seq(n);i=bisect.bisect_left([x[0] for x in values],t)-1
            return values[i][1] if i>=0 else 'x'
        edges=[t for t,v in seq('clk') if v=='1' and before('reset_n',t)=='1']
        def hs(n,t):return before(n+'valid',t)=='1' and before(n+'ready',t)=='1'
        aw=None;w=None;orders={}
        for tick in edges:
            if hs('aw',tick):aw=tick
            if hs('w',tick):w=tick
            if aw is not None and w is not None:
                name='address-first' if aw<w else 'data-first' if w<aw else 'simultaneous'
                orders.setdefault(name,(min(aw,w)-15000,max(aw,w)+65000))
                aw=None;w=None
        crops=[]
        if adapter==0:
            for name in ['address-first','data-first','simultaneous']:crops.append((name,*orders[name]))
            tick=next(t for t in edges if before('bvalid',t)=='1' and before('bready',t)=='0')
            crops.append(('b-backpressure',tick-25000,tick+75000))
            tick=next(t for t,v in seq('reset_n') if t>0 and v=='0' and before('wvalid',t)=='0' and before('awvalid',t)=='1')
            crops.append(('partial-write-reset',tick-25000,tick+65000))
        elif adapter==1:
            crops.append(('independent-write-stalls',*orders['data-first']))
            tick=next(t for t in edges if hs('ar',t))
            crops.append(('read-and-cpu-completion',tick-35000,tick+100000))
        else:
            tick=next(t for t in edges if hs('w',t) and int(before('wstrb',t),2)==5)
            crops.append(('partial-strobe-integration',tick-35000,tick+115000))
        for name,start,end in crops:
            signals=['clk','reset_n','awvalid','awready','awaddr','wvalid','wready','wdata','wstrb','bvalid','bready','bresp']
            if 'read' in name:signals=['clk','reset_n','arvalid','arready','araddr','rvalid','rready','rdata','rresp','req_valid','req_ready','response_valid','response_data']
            if adapter==2:signals+=['req_valid','req_ready','response_valid']
            dest=a.output/f'adapter-{adapter}-{name}.svg'
            code=vcd_to_svg.main(['--vcd',str(path),'--signals',*['axil_uvm_top.bus.'+s for s in signals],
              '--start',str(max(0,start)),'--end',str(min(trace.last_tick,end)),'--output',str(dest),
              '--origin','simulator','--title',f'Measured AXI4-Lite UVM/SVA: adapter {adapter}, {name} (exact capture bytes)'])
            if code:raise RuntimeError('Renderer failed')
            meta=json.loads(dest.with_suffix('.json').read_text());raw=path.read_bytes()
            meta.update(source_relative_path=os.path.relpath(path,a.output).replace('\\','/'),source_revision=r['source_revision'],
                source_representation='original simulator capture bytes; committed without conversion',captured_sha256=hashlib.sha256(raw).hexdigest(),
                crlf_count=raw.count(b'\r\n'),lf_count=raw.count(b'\n'))
            dest.with_suffix('.json').write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
            manifest['figures'].append(dict(figure=dest.name,metadata=dest.with_suffix('.json').name,**meta))
    (a.output/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    return 0
if __name__=='__main__':raise SystemExit(main())
