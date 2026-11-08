#!/usr/bin/env python3
"""Separate APB UVM milestone. Required omissions/errors always return nonzero.

--mode deterministic executes UVM + SVA + procedural requirements, no randomize
or covergroups. --mode coverage also requires covergroup simulation, UCDB and
an exported nonempty functional coverage report; blocked does NOT mean PASS.
"""
import argparse
import datetime
import json
from pathlib import Path
import re
import subprocess
import sys
from advanced_sim import digest, failure, git, run, tool

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--sim-bin',type=Path,required=True)
    ap.add_argument('--uvm-lib',type=Path,required=True)
    ap.add_argument('--uvm-include',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--mode',choices=['deterministic','coverage'],default='deterministic')
    ap.add_argument('--timeout',type=int,default=90)
    ap.add_argument('--source-root',type=Path,help='Optional local Git mirror root; pins still verified')
    ap.add_argument('--inject-read-fault',action='store_true',help='Disposable fault control: expected wrapper result is NONZERO')
    ap.add_argument('--adapters',nargs='+',type=int,choices=[0,1,2],default=[0,1,2])
    args=ap.parse_args()
    if args.output.exists() or args.timeout<1: ap.error('Require fresh output and positive timeout')
    args.output.mkdir(parents=True); out=args.output.resolve()
    repo=Path(__file__).resolve().parent.parent
    src=repo/'verification/apb_uvm'
    report=dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                source_revision=git(repo,'rev-parse','HEAD'),source_dirty=bool(git(repo,'status','--porcelain')),
                mode=args.mode,seed='0x28A6BEEF (deterministic vectors; no randomize call)',
                fault_control=args.inject_read_fault,suites=[],source_locks=[],
                functional_coverage='NOT RUN' if args.mode=='deterministic' else 'PENDING',
                constrained_randomization='NOT RUN',command=[sys.executable,*sys.argv])
    # Hash every new execution input even for exploratory dirty-tree runs.
    report['input_sha256']={str(p.relative_to(repo)):digest(p) for p in
      [*src.glob('*.sv'),src/'sources.json',Path(__file__),repo/'scripts/advanced_sim.py',repo/'checkers/apb_ram_responder.sv']}
    cmds=[]
    r,t=run([tool(args.sim_bin,'vsim'),'-version'],out,args.timeout,out/'version.log')
    report['version_command']=r; report['simulator_version']=t.strip()
    prereq=failure(r,t) or (None if (args.uvm_include/'uvm_macros.svh').is_file() and args.uvm_lib.is_dir() else 'UVM_LIBRARY_MISSING')
    locks=json.loads((src/'sources.json').read_text())
    dut={}
    for lock in locks['sources']:
        if lock['adapter'] not in args.adapters: continue
        dest=out/'sources'/lock['repository']; dest.parent.mkdir(exist_ok=True)
        url=str(args.source_root/lock['repository']) if args.source_root else f"https://github.com/{locks['owner']}/{lock['repository']}.git"
        entry=dict(lock,commands=[]); report['source_locks'].append(entry)
        for command in [['git','-c','core.autocrlf=false','clone','--quiet',url,str(dest)],
                        ['git','-C',str(dest),'checkout','--quiet','--detach',lock['revision']]]:
            r,t=run(command,out,args.timeout,out/f"source-{lock['adapter']}-{len(entry['commands'])}.log")
            entry['commands'].append(r)
            if failure(r,t): entry['error']=failure(r,t);break
        if 'error' not in entry:
            entry['observed_revision']=git(dest,'rev-parse','HEAD')
            entry['clean']=not bool(git(dest,'status','--porcelain'))
            if entry['observed_revision']!=lock['revision'] or not entry['clean']:entry['error']='SOURCE_MISMATCH'
            else:dut[lock['adapter']]=dest/lock['rtl']
    def execute(name,files,top,defines,plus,marker,coverage=False,wave=False):
        wd=out/name;wd.mkdir()
        result=dict(name=name,status='NOT RUN',commands=[]);report['suites'].append(result)
        if prereq: result['reason']=prereq;return result
        common=['-L',str(args.uvm_lib),'+incdir+'+str(args.uvm_include)]
        do='onerror {quit -force -code 1}; '
        if wave: do+='vcd file capture.vcd; vcd add /apb_uvm_top/bus/*; '
        do+='run -all; '
        if wave: do+='vcd flush; '
        if coverage: do+='coverage save coverage.ucdb; '
        do+='quit -force -code 0'
        commands=[['vlib','work'],['vlog','-sv','-work','work',*common,*defines,*map(str,files)],
                  ['vsim','-c','-onfinish','stop','-voptargs=+acc','-sv_seed','682016495',
                   '-L',str(args.uvm_lib),*(['-coverage'] if coverage else []),'work.'+top,*plus,'-do',do]]
        for i,c in enumerate(commands):
            c[0]=tool(args.sim_bin,c[0]); r,t=run(c,wd,args.timeout,wd/f'{i}.log');result['commands'].append(r)
            reason=failure(r,t,marker if i==2 else None)
            if reason: result.update(status='NOT RUN' if reason=='LICENCE_BLOCKED' else 'FAIL',reason=reason);return result
        result.update(status='PASS',reason='EXECUTED')
        if top=='apb_uvm_top':
            match=re.search(r'APB_UVM_PASS adapter=(\d+) transfers=(\d+) comparisons=(\d+) resets=(\d+) aborted=(\d+) assertions=0',t)
            if not match:result.update(status='FAIL',reason='MISSING_COUNTS');return result
            result['counts']=dict(zip(['adapter','transfers','comparisons','resets','aborted'],map(int,match.groups())))
            req=wd/'requirements.json'
            if not req.is_file():result.update(status='FAIL',reason='MISSING_REQUIREMENT_REPORT');return result
            result['requirements']=json.loads(req.read_text())
        if wave:
            capture=wd/'capture.vcd'
            if not capture.is_file() or capture.stat().st_size==0:result.update(status='FAIL',reason='MISSING_VCD');return result
            result['capture_sha256']=digest(capture)
        if coverage:
            ucdb=wd/'coverage.ucdb'
            if not ucdb.is_file():result.update(status='FAIL',reason='MISSING_UCDB');return result
            c=[tool(args.sim_bin,'vcover'),'report','-details','-cvg','-output','coverage.txt','coverage.ucdb']
            r,t=run(c,wd,args.timeout,wd/'3.log');result['commands'].append(r)
            dest=wd/'coverage.txt'
            reason=failure(r,t)
            if reason or not dest.is_file() or not re.search('Covergroup|Coverpoint',dest.read_text(),re.I):
                result.update(status='FAIL',reason=reason or 'MISSING_FUNCTIONAL_COVERAGE_REPORT')
            else:result['coverage_report_sha256']=digest(dest)
        return result
    for adapter in args.adapters:
        if adapter<2 and adapter not in dut:
            report['suites'].append(dict(name=f'adapter-{adapter}',status='NOT RUN',reason='SOURCE_UNAVAILABLE'));continue
        defines=[f'+define+APB_ADAPTER={adapter}']
        if adapter<2:defines+=['+define+'+locks['sources'][adapter]['define']]
        if args.mode=='coverage':defines+=['+define+APB_ENABLE_COVERGROUP']
        files=[src/'apb_bus.sv']+([dut[adapter]] if adapter<2 else [])+[
            repo/'checkers/apb_ram_responder.sv',src/'apb_adapter.sv',src/'apb_assertions.sv',
            src/'apb_uvm_pkg.sv',src/'apb_uvm_top.sv']
        execute(f'adapter-{adapter}',files,'apb_uvm_top',defines,
                ['+FAULT_READ'] if args.inject_read_fault else [],r'^# APB_UVM_PASS adapter='+str(adapter)+r' ',
                coverage=args.mode=='coverage',wave=True)
    ids=['SETUP','WAIT_HOLD','ACCESS_ENTRY','ENABLE_SELECT','ERROR_ELIGIBILITY']
    for case in range(6):
        result=execute(f'assertion-{case}',[src/'apb_bus.sv',src/'apb_assertions.sv',src/'apb_assertion_control.sv'],
                       'apb_assertion_control',[],[f'+CASE={case}']+(['+EXPECT_ASSERT'] if case<5 else []),
                       rf'^# APB_SVA_CONTROL_PASS case={case} detections={0 if case==5 else 1}\s*$')
        if result['status']=='PASS' and case<5:
            text=(out/f'assertion-{case}/2.log').read_text()
            observed=re.findall(r'^# APB_ASSERT_DETECTED (\w+) time=',text,re.M)
            if observed!=[ids[case]]:result.update(status='FAIL',reason='UNEXPECTED_ASSERTION_DETECTION')
    report['aggregate_exit_code']=0 if report['suites'] and all(s['status']=='PASS' for s in report['suites']) else 1
    if args.mode=='coverage':report['functional_coverage']='EXPORTED' if all(s['status']=='PASS' for s in report['suites'] if s['name'].startswith('adapter')) else 'NOT RUN / INCOMPLETE'
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({k:report[k] for k in ['source_revision','source_dirty','mode','functional_coverage','aggregate_exit_code']},indent=2))
    for s in report['suites']:print(s['name'],s['status'],s.get('reason'),s.get('counts',''))
    return report['aggregate_exit_code']
if __name__=='__main__':raise SystemExit(main())
