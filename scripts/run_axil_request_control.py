#!/usr/bin/env python3
"""Run one synthetic public-pin request oracle control, serially.

Legal control must return 0. Duplicate-write/read controls must return nonzero
for the intended UVM fatal; the full milestone parent qualifies that cause.
A permissive old checker returns 0 and is explicitly labelled a missed control.
No DUT RTL is changed or instantiated in these checker-only simulations.
"""
import argparse
import datetime
import json
from pathlib import Path
import re
import sys
from advanced_sim import digest, failure, git, run, tool
from axil_accounting import validate_accounting

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--adapter',type=int,choices=[1,2],required=True)
    ap.add_argument('--mode',choices=['legal','duplicate-write','duplicate-read'],required=True)
    ap.add_argument('--sim-bin',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/win64'))
    ap.add_argument('--uvm-lib',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/uvm-1.2'))
    ap.add_argument('--uvm-include',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src'))
    ap.add_argument('--timeout',type=int,default=90)
    args=ap.parse_args()
    if args.output.exists() or args.timeout<1:ap.error('Require fresh output and positive timeout')
    args.output.mkdir(parents=True);out=args.output.resolve()
    repo=Path(__file__).resolve().parent.parent;src=repo/'verification/axil_uvm'
    mode=['legal','duplicate-write','duplicate-read'].index(args.mode)
    files=[src/n for n in ['axil_bus.sv','axil_assertions.sv','axil_uvm_pkg.sv','axil_request_control.sv']]
    report=dict(source_revision=git(repo,'rev-parse','HEAD'),source_dirty=bool(git(repo,'status','--porcelain')),
        mode=args.mode,adapter=args.adapter,seed=682016495,scope='synthetic public-pin checker control; no DUT',
        command=[sys.executable,*sys.argv],commands=[],status='NOT RUN',
        input_sha256={p.relative_to(repo).as_posix():digest(p) for p in [*files,Path(__file__),repo/'scripts/advanced_sim.py',repo/'scripts/axil_accounting.py']},
        started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    r,text=run([tool(args.sim_bin,'vsim'),'-version'],out,args.timeout,out/'version.log')
    report['version_command']=r;report['simulator_version']=text.strip();reason=failure(r,text)
    if not (args.uvm_include/'uvm_macros.svh').is_file() or not args.uvm_lib.is_dir():reason=reason or 'UVM_LIBRARY_MISSING'
    commands=[['vlib','work'],['vlog','-sv','-work','work','-L',str(args.uvm_lib),'+incdir+'+str(args.uvm_include),f'+define+AXIL_ADAPTER={args.adapter}',*map(str,files)],
        ['vsim','-c','-onfinish','stop','-voptargs=+acc','-sv_seed','682016495','-L',str(args.uvm_lib),'work.axil_request_control',f'+CONTROL={mode}',
         '-do','onerror {quit -force -code 1}; vcd file capture.vcd; vcd add /axil_request_control/bus/*; run -all; vcd flush; quit -force -code 0']]
    if not reason:
        for i,command in enumerate(commands):
            command[0]=tool(args.sim_bin,command[0]);r,text=run(command,out,args.timeout,out/f'{i}.log');report['commands'].append(r)
            reason=failure(r,text,rf'^# AXIL_REQUEST_CONTROL_PASS adapter={args.adapter} mode={mode} ' if i==2 else None)
            if reason:break
    if not reason:
        m=re.search(r'AXIL_REQUEST_CONTROL_PASS adapter=(\d+) mode=(\d+) requests=(\d+) completions=(\d+) writes=(\d+) reads=(\d+) cancelled=(\d+) assertions=0',text)
        if not m:reason='MISSING_COUNTS'
        else:
            report['counts']=dict(zip(['adapter','mode','requests','completed','writes','reads','cancelled'],map(int,m.groups())))
            # Negative runs against the old checker must be allowed to reveal
            # its false acceptance. They cannot qualify a full milestone pass.
            if mode==0:
                try:
                    report['accounting']=json.loads((out/'accounting.json').read_text())
                    validate_accounting(report['accounting'],report['counts'],args.adapter)
                    if report['accounting']['cancelled_b']!=1 or report['accounting']['cancelled_r']!=1:
                        raise ValueError('Post-bus/pre-CPU reset stages missing')
                except (OSError,ValueError,KeyError) as error:reason='ACCOUNTING_ERROR: '+str(error)
    report.update(status='FAIL' if reason else 'PASS',reason=reason or 'EXECUTED',wrapper_exit_code=int(bool(reason)),
        missed_negative_control=bool(mode and not reason),finished_utc=datetime.datetime.now(datetime.timezone.utc).isoformat())
    if (out/'capture.vcd').is_file():report['capture_sha256']=digest(out/'capture.vcd')
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['source_revision','source_dirty','adapter','mode','status','reason','wrapper_exit_code','missed_negative_control']}))
    return report['wrapper_exit_code']
if __name__=='__main__':raise SystemExit(main())
