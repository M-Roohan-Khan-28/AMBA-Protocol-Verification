#!/usr/bin/env python3
"""Separate deterministic AXI4-Lite UVM/SVA regression; sequential sessions only.

Default: three real-RTL adapters, fourteen SVA and six request-oracle controls.
Diagnostic selections/fault runs never claim the complete milestone PASS.
No randomization or functional covergroup execution is attempted.
"""
import argparse
import datetime
import json
from pathlib import Path
import re
import sys
from advanced_sim import digest, failure, git, run, tool
from axil_accounting import validate_accounting

IDS=['AW_HOLD','W_HOLD','AR_HOLD','B_HOLD','R_HOLD',
     'B_ELIGIBILITY','B_ELIGIBILITY','B_ELIGIBILITY','B_ELIGIBILITY',
     'R_ELIGIBILITY','R_ELIGIBILITY','B_ELIGIBILITY','B_ELIGIBILITY',None]

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--sim-bin',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/win64'))
    ap.add_argument('--uvm-lib',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/uvm-1.2'))
    ap.add_argument('--uvm-include',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src'))
    ap.add_argument('--timeout',type=int,default=90)
    ap.add_argument('--diagnostic-adapters',type=int,nargs='+',choices=[0,1,2],help='Selected adapters only, without qualifications; NOT a full regression')
    ap.add_argument('--fault',choices=['data','address','drop-response'])
    args=ap.parse_args()
    if args.output.exists() or args.timeout<1:ap.error('Require a fresh output and positive timeout')
    args.output.mkdir(parents=True);out=args.output.resolve()
    repo=Path(__file__).resolve().parent.parent;src=repo/'verification/axil_uvm'
    adapters=args.diagnostic_adapters if args.diagnostic_adapters is not None else [0,1,2]
    report=dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
      source_revision=git(repo,'rev-parse','HEAD'),source_dirty=bool(git(repo,'status','--porcelain')),
      scope='diagnostic' if args.diagnostic_adapters is not None else 'full deterministic milestone',
      mode='deterministic',seed=682016495,seed_hex='0x28A6BEEF',fault_control=args.fault,
      functional_coverage='NOT RUN',constrained_randomization='NOT RUN',original_advanced_environments='NOT RUN',
      command=[sys.executable,*sys.argv],suites=[],serial_execution=True)
    report['input_sha256']={p.relative_to(repo).as_posix():digest(p) for p in [*src.glob('*.sv'),src/'sources.json',Path(__file__),repo/'scripts/advanced_sim.py',repo/'scripts/axil_accounting.py',repo/'scripts/run_axil_request_control.py']}
    r,t=run([tool(args.sim_bin,'vsim'),'-version'],out,args.timeout,out/'version.log')
    report['version_command']=r;report['simulator_version']=t.strip()
    prereq=failure(r,t)
    if not (args.uvm_include/'uvm_macros.svh').is_file() or not args.uvm_lib.is_dir():prereq=prereq or 'UVM_LIBRARY_MISSING'
    lock=json.loads((src/'sources.json').read_text());dest=out/'source'
    entry=dict(lock,commands=[]);report['source_lock']=entry
    for cmd in [ ['git','clone','--quiet','--config','core.autocrlf=false','--config','core.longpaths=true',f"https://github.com/{lock['owner']}/{lock['repository']}.git",str(dest)],
                 ['git','-C',str(dest),'checkout','--quiet','--detach',lock['revision']] ]:
        r,t=run(cmd,out,args.timeout,out/f"source-{len(entry['commands'])}.log");entry['commands'].append(r)
        if failure(r,t):entry['error']=failure(r,t);break
    if 'error' not in entry:
        entry['observed_revision']=git(dest,'rev-parse','HEAD');entry['clean']=not bool(git(dest,'status','--porcelain'))
        if entry['observed_revision']!=lock['revision'] or not entry['clean']:entry['error']='SOURCE_MISMATCH'
        entry['rtl_sha256']={p:digest(dest/p) for p in lock['files']}
    def execute(name,files,top,defines,plus,marker,wave=False):
        wd=out/name;wd.mkdir();s=dict(name=name,status='NOT RUN',commands=[]);report['suites'].append(s)
        if prereq:s['reason']=prereq;return s
        if top=='axil_uvm_top' and entry.get('error'):s['reason']=entry['error'];return s
        do='onerror {quit -force -code 1}; '
        if wave:do+='vcd file capture.vcd; vcd add /axil_uvm_top/bus/*; '
        do+='run -all; '
        if wave:do+='vcd flush; '
        do+='quit -force -code 0'
        commands=[['vlib','work'],['vlog','-sv','-work','work','-L',str(args.uvm_lib),'+incdir+'+str(args.uvm_include),*defines,*map(str,files)],
                  ['vsim','-c','-onfinish','stop','-voptargs=+acc','-sv_seed','682016495','-L',str(args.uvm_lib),'work.'+top,*plus,'-do',do]]
        for i,c in enumerate(commands):
            c[0]=tool(args.sim_bin,c[0]);r,t=run(c,wd,args.timeout,wd/f'{i}.log');s['commands'].append(r)
            reason=failure(r,t,marker if i==2 else None)
            if reason:s.update(status='NOT RUN' if reason=='LICENCE_BLOCKED' else 'FAIL',reason=reason);return s
        s.update(status='PASS',reason='EXECUTED')
        if wave:
            m=re.search(r'AXIL_UVM_PASS adapter=(\d+) completed=(\d+) writes=(\d+) reads=(\d+) comparisons=(\d+) resets=(\d+) cancelled=(\d+) assertions=0',t)
            if not m:s.update(status='FAIL',reason='MISSING_COUNTS');return s
            s['counts']=dict(zip(['adapter','completed','writes','reads','comparisons','resets','cancelled'],map(int,m.groups())))
            req=wd/'requirements.json';capture=wd/'capture.vcd'
            if not req.is_file() or not capture.is_file() or capture.stat().st_size==0:s.update(status='FAIL',reason='MISSING_REQUIREMENTS_OR_WAVE');return s
            s['requirements']=json.loads(req.read_text());s['capture_sha256']=digest(capture)
            try:
                s['accounting']=json.loads((wd/'accounting.json').read_text())
                validate_accounting(s['accounting'],s['counts'],s['counts']['adapter'])
            except (OSError,ValueError,KeyError) as error:s.update(status='FAIL',reason='ACCOUNTING_ERROR: '+str(error))
        return s
    for adapter in adapters:
        files=[src/'axil_bus.sv',*[dest/p for p in lock['files']],src/'axil_adapter.sv',src/'axil_assertions.sv',src/'axil_uvm_pkg.sv',src/'axil_uvm_top.sv']
        plus=[] if not args.fault else ['+'+{'data':'FAULT_DATA','address':'FAULT_ADDRESS','drop-response':'FAULT_DROP_RESPONSE'}[args.fault]]
        execute(f'adapter-{adapter}',files,'axil_uvm_top',[f'+define+AXIL_ADAPTER={adapter}'],plus,rf'^# AXIL_UVM_PASS adapter={adapter} ',True)
    if args.diagnostic_adapters is None:
        for case,expected in enumerate(IDS):
            s=execute(f'assertion-{case}',[src/'axil_bus.sv',src/'axil_assertions.sv',src/'axil_assertion_control.sv'],
              'axil_assertion_control',[],[f'+CASE={case}']+(['+EXPECT_ASSERT'] if expected else []),
              rf'^# AXIL_SVA_CONTROL_PASS case={case} detections={int(expected is not None)}\s*$')
            if s['status']=='PASS':
                text=(out/s['name']/'2.log').read_text();observed=re.findall(r'^# AXIL_ASSERT_DETECTED (\w+) time=',text,re.M)
                s['expected_detections']=[] if expected is None else [expected];s['observed_detections']=observed
                if observed!=s['expected_detections']:s.update(status='FAIL',reason='WRONG_ASSERTION_DETECTIONS')
        # Child wrappers return nonzero on a genuine fatal. The parent accepts
        # only the individual expected oracle ID, with no SVA/other errors.
        for adapter in [1,2]:
            for mode in ['legal','duplicate-write','duplicate-read']:
                name=f'request-{adapter}-{mode}';child=out/name
                command=[sys.executable,str(repo/'scripts/run_axil_request_control.py'),'--adapter',str(adapter),'--mode',mode,
                    '--output',str(child),'--sim-bin',str(args.sim_bin),'--uvm-lib',str(args.uvm_lib),'--uvm-include',str(args.uvm_include),'--timeout',str(args.timeout)]
                r,text=run(command,repo,4*args.timeout+30,out/(name+'-wrapper.log'))
                s=dict(name=name,status='FAIL',reason='CONTROL_FAILED',commands=[r]);report['suites'].append(s)
                try:
                    result=json.loads((child/'results.json').read_text());log=(child/'2.log').read_text()
                    s['child_result']=result;s['child_wrapper_exit_code']=r['exit_code']
                    assert not r['timed_out'] and len(result['commands'])==3
                    assert all(not c['timed_out'] and c['exit_code']==0 for c in result['commands'])
                    if mode=='legal':
                        assert r['exit_code']==0 and result['status']=='PASS' and result['wrapper_exit_code']==0
                    else:
                        expected='REQUEST_DUPLICATE_WRITE' if mode=='duplicate-write' else 'REQUEST_DUPLICATE_READ'
                        fatals=re.findall(r'^# UVM_FATAL .*?\[(\w+)\]',log,re.M)
                        assert r['exit_code']==result['wrapper_exit_code']==1 and result['status']=='FAIL'
                        assert result['reason']=='PROCESS_OR_SIMULATOR_ERROR' and fatals==[expected]
                        assert not re.search(r'^# UVM_ERROR .*?@|\*\* (?:Error|Fatal)|AXIL_ASSERT_DETECTED|AXIL_REQUEST_CONTROL_PASS',log,re.M)
                        assert f'AXIL_REQUEST_CONTROL_INJECT adapter={adapter} mode={1 if mode=="duplicate-write" else 2} assertions=0' in log
                        s['expected_fatal']=expected;s['observed_fatals']=fatals
                    s.update(status='PASS',reason='EXECUTED' if mode=='legal' else 'EXPECTED_ORACLE_DETECTION')
                except (OSError,ValueError,KeyError,AssertionError) as error:s['detail']=str(error)
    report['required_substeps']=len(adapters)+(len(IDS)+6 if args.diagnostic_adapters is None else 0)
    report['aggregate_exit_code']=0 if len(report['suites'])==report['required_substeps'] and all(s['status']=='PASS' for s in report['suites']) else 1
    report['milestone_pass']=report['aggregate_exit_code']==0 and args.diagnostic_adapters is None and not args.fault
    report['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat()
    (out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    for s in report['suites']:print(s['name'],s['status'],s.get('reason'),s.get('counts',''))
    print(json.dumps({k:report[k] for k in ['source_revision','source_dirty','scope','aggregate_exit_code','milestone_pass']},indent=2))
    return report['aggregate_exit_code']
if __name__=='__main__':raise SystemExit(main())
