#!/usr/bin/env python3
"""Crop actual UVM VCDs; preserve the simulator's exact bytes and representation."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'tools'))
import vcd_to_svg

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--run',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    a=ap.parse_args()
    if a.output.exists():ap.error('Use a fresh figure directory')
    results=json.loads((a.run/'results.json').read_text())
    if results['aggregate_exit_code'] or results['fault_control']:ap.error('Require a passing unmodified regression')
    a.output.mkdir(parents=True)
    signals=['clk','reset_n','select','enable','write','addr','wdata','ready','error','rdata']
    manifest={'source_revision':results['source_revision'],'byte_policy':'Exact simulator capture bytes; Git -text; no newline conversion','figures':[]}
    for adapter,event in [(0,'alias'),(0,'reset'),(1,'error'),(2,'wait'),(2,'reset')]:
        path=a.run/f'adapter-{adapter}'/'capture.vcd'
        trace=vcd_to_svg.parse_vcd(path)
        if trace.timescale!='1ps':raise ValueError('Expected 1ps capture; do not guess tick conversion')
        def transitions(name):return trace.events[trace.signals['apb_uvm_top.bus.'+name].code]
        if event=='alias': tick=next(t for t,v in transitions('addr') if 'x' not in v and int(v,2)==1)
        elif event=='reset':tick=next(t for t,v in reversed(transitions('reset_n')) if t>0 and v=='0')
        elif event=='error':tick=next(t for t,v in transitions('error') if v=='1')
        else:tick=40000
        start=max(0,tick-30000); end=min(trace.last_tick,tick+150000)
        dest=a.output/f'adapter-{adapter}-{event}.svg'
        title=f'Measured deterministic UVM / SVA: adapter {adapter}, {event} (exact capture bytes)'
        code=vcd_to_svg.main(['--vcd',str(path),'--signals',*['apb_uvm_top.bus.'+n for n in signals],
            '--start',str(start),'--end',str(end),'--output',str(dest),'--origin','simulator','--title',title])
        if code:raise RuntimeError('Waveform renderer failed')
        md=dest.with_suffix('.json'); meta=json.loads(md.read_text())
        raw=path.read_bytes()
        meta.update(source_representation='original simulator capture bytes, committed without conversion',
                    source_relative_path=os.path.relpath(path,a.output).replace('\\','/'),
                    source_revision=results['source_revision'],crlf_count=raw.count(b'\r\n'),
                    lf_count=raw.count(b'\n'),captured_sha256=hashlib.sha256(raw).hexdigest())
        md.write_text(json.dumps(meta,indent=2)+'\n',encoding='utf-8')
        manifest['figures'].append(dict(figure=dest.name,metadata=md.name,**meta))
    (a.output/'MANIFEST.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    return 0
if __name__=='__main__':raise SystemExit(main())
