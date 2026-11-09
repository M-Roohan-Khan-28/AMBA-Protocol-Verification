#!/usr/bin/env python3
"""Separate deterministic DMA milestone; inventory-driven, serial and fail closed."""
import argparse,datetime,json,re,sys,time
from pathlib import Path
from advanced_sim import digest,failure,git,run,tool
from dma_accounting import validate

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--select',nargs='+',help='Diagnostic selection; never a complete milestone pass')
    ap.add_argument('--sim-bin',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/win64'))
    ap.add_argument('--uvm-lib',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/uvm-1.2'))
    ap.add_argument('--uvm-include',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src'))
    ap.add_argument('--timeout',type=int,default=90)
    ap.add_argument('--global-timeout',type=int,default=2400)
    ap.add_argument('--expected-env-sha',help='Full environment SHA required for a full release run')
    ap.add_argument('--raw-fault',action='store_true',help='Internal diagnostic child: preserve the genuine nonzero fault result')
    ap.add_argument('--source-cache',type=Path,help=argparse.SUPPRESS)
    ap.add_argument('--dut-mirror',type=Path,help='Optional clean local DUT mirror at the exact lock; transport is recorded')
    a=ap.parse_args();repo=Path(__file__).resolve().parent.parent;src=repo/'verification/dma_uvm'
    if a.output.exists() or a.timeout<1 or a.global_timeout<1:ap.error('Require fresh output and positive bounds')
    out=a.output.resolve();out.mkdir(parents=True)
    inventory=json.loads((src/'inventory.json').read_text());allsteps=inventory['required_substeps']
    names=[s['name'] for s in allsteps];assert names and len(names)==len(set(names))
    available=allsteps+inventory.get('diagnostic_substeps',[])
    if a.select and any(n not in [s['name'] for s in available] for n in a.select):ap.error('Unknown substep')
    steps=[s for s in available if s['name'] in a.select] if a.select else allsteps
    report=dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),command=[sys.executable,*sys.argv],
      source_revision=git(repo,'rev-parse','HEAD'),source_dirty=bool(git(repo,'status','--porcelain')),serial_execution=True,
      selection=a.select,raw_fault=a.raw_fault,seed=682016495,seed_hex='0x28A6BEEF',functional_coverage='NOT RUN',constrained_randomization='NOT RUN',original_advanced_alu_apb='NOT RUN',suites=[],
      expected_inventory=names,required_selected=[s['name'] for s in steps],aggregate_exit_code=1,milestone_pass=False)
    report['input_sha256']={p.relative_to(repo).as_posix():digest(p) for p in [*src.glob('*'),Path(__file__),repo/'scripts/advanced_sim.py',repo/'scripts/dma_accounting.py'] if p.is_file()}
    report['expected_environment_revision']=a.expected_env_sha
    report['runner_revision']=git(repo,'log','-1','--format=%H','--','scripts/run_dma_uvm.py')
    report['inventory_revision']=git(repo,'log','-1','--format=%H','--','verification/dma_uvm/inventory.json')
    report['configuration']={'sim_bin':str(a.sim_bin),'uvm_lib':str(a.uvm_lib),'uvm_include':str(a.uvm_include),
      'timeout_per_command':a.timeout,'global_timeout':a.global_timeout,'python_version':sys.version,
      'vendor_input_sha256':{str(p):digest(p) for p in [a.uvm_include/'uvm_pkg.sv',a.uvm_include/'uvm_macros.svh',tool(a.sim_bin,'vsim'),tool(a.sim_bin,'vlog')] if p.is_file()}}
    start=time.monotonic()
    def save():(out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    def invoke(cmd,cwd,log):return run(cmd,cwd,max(1,min(a.timeout,int(a.global_timeout-(time.monotonic()-start)))),log)
    v,t=invoke([tool(a.sim_bin,'vsim'),'-version'],out,out/'version.log');report['version_command']=v;report['simulator_version']=t.strip()
    prereq=failure(v,t)
    if a.expected_env_sha and (len(a.expected_env_sha)!=40 or a.expected_env_sha!=report['source_revision'] or report['source_dirty']):prereq='ENVIRONMENT_SOURCE_MISMATCH'
    if not a.select and not a.expected_env_sha:prereq='FULL_RUN_REQUIRES_ENVIRONMENT_SHA'
    source=out/'source';lock=json.loads((src/'sources.json').read_text())
    if any(s['kind']!='sva' for s in steps):
        report['source_lock']=dict(lock,commands=[])
        url=f'https://github.com/{lock["owner"]}/{lock["repository"]}.git';supplier=url
        mirror=a.source_cache or a.dut_mirror
        if a.source_cache and (not a.raw_fault or a.dut_mirror):ap.error('Source cache is only for internal fault children')
        if mirror:
            assert git(mirror,'rev-parse','HEAD')==lock['revision'] and not git(mirror,'status','--porcelain')
            assert git(mirror,'remote','get-url','origin')==url
            supplier=str(mirror.resolve())
        report['source_lock']['supplier']=supplier
        report['source_lock']['transport']='verified_local_mirror' if mirror else 'GitHub_HTTPS'
        for command in [['git','clone','--quiet','--no-hardlinks','--config','core.autocrlf=false','--config','core.longpaths=true',supplier,str(source)],['git','-C',str(source),'checkout','--quiet','--detach',lock['revision']],['git','-C',str(source),'remote','set-url','origin',url]]:
            c,text=invoke(command,out,out/f'source-{len(report["source_lock"]["commands"])}.log');report['source_lock']['commands'].append(c)
            if failure(c,text):prereq=prereq or failure(c,text);break
        else:
            observed=git(source,'rev-parse','HEAD');clean=not bool(git(source,'status','--porcelain'))
            report['source_lock'].update(observed_revision=observed,clean=clean,rtl_sha256={p:digest(source/p) for p in lock['files']})
            if observed!=lock['revision'] or not clean:prereq='DUT_SOURCE_MISMATCH'
    for entry in steps:
        wd=out/entry['name'];wd.mkdir();s=dict(name=entry['name'],kind=entry['kind'],status='NOT RUN',commands=[]);report['suites'].append(s)
        if prereq or time.monotonic()-start>=a.global_timeout:s['reason']=prereq or 'GLOBAL_TIMEOUT';save();continue
        if entry['kind']=='fault' and not a.raw_fault:
            child=wd/'child'
            cmd=[sys.executable,str(Path(__file__)),'--select',entry['name'],'--raw-fault','--output',str(child),'--sim-bin',str(a.sim_bin),'--uvm-lib',str(a.uvm_lib),'--uvm-include',str(a.uvm_include),'--timeout',str(a.timeout)]
            cmd+=['--source-cache',str(source)]
            if a.expected_env_sha:cmd+=['--expected-env-sha',a.expected_env_sha]
            c,text=run(cmd,repo,max(1,min(6*a.timeout,int(a.global_timeout-(time.monotonic()-start)))),wd/'child-wrapper.log');s['commands'].append(c)
            s.update(status='FAIL',reason='FAULT_NOT_QUALIFIED',child_wrapper_exit=c['exit_code'],passing_control=entry['passing_control'])
            try:
                result=json.loads((child/'results.json').read_text());log=(child/entry['name']/'2.log').read_text();childstep=result['suites'][0]
                assert c['exit_code']==result['aggregate_exit_code']==1 and not c['timed_out']
                assert result['source_revision']==report['source_revision'] and result['input_sha256']==report['input_sha256']
                assert result['source_lock']['observed_revision']==lock['revision'] and result['source_lock']['clean']
                assert len(result['suites'])==1 and len(childstep['commands'])==3
                assert all(x['exit_code']==0 and not x['timed_out'] for x in childstep['commands'])
                assert childstep['status']=='FAIL' and not re.search(r'\*\* (?:Error|Fatal)|^# UVM_ERROR .*?@|DMA_SVA_DETECTED',log,re.M)
                fatals=re.findall(r'^# UVM_FATAL .*?\[(\w+)\]',log,re.M)
                if entry['fault']=='missing_marker':
                    assert not fatals and childstep['reason']=='MISSING_RESULT_MARKER'
                    assert re.search(r'^# DMA_UVM_PASS cases=1 assertions=0 seed=0x28A6BEEF\s*$',log,re.M)
                else:
                    assert fatals==[entry['expected_fatal']] and childstep['reason']=='PROCESS_OR_SIMULATOR_ERROR'
                    assert 'DMA_UVM_PASS' not in log
                    if entry['fault'].startswith('duplicate'):
                        kind=entry['fault'].split('_')[1]
                        assert f'DMA_DUPLICATE_ACCEPTED kind={kind} bit_identical=1' in log
                        assert f'DMA_FAULT_BASELINE_MEMORY_OK kind={entry["fault"]} before_duplicate=1' in log
                s.update(status='PASS',reason='EXPECTED_CHILD_FAILURE',expected_fatal=entry['expected_fatal'],observed_fatals=fatals,child_result=result)
            except (OSError,ValueError,KeyError,AssertionError) as error:s['detail']=str(error)
            save();print(s['name'],s['status'],s['reason'],'child exit',c['exit_code'],flush=True);continue
        if entry['kind']=='sva':
            files=[src/'dma_bus.sv',src/'dma_assertions.sv',src/'dma_sva_control.sv'];top='dma_sva_control'
            plus=['+SCENARIO='+entry['scenario']]+(['+EXPECT_SVA='+entry['expected']] if entry['expected'] else [])
            marker=rf'^# DMA_SVA_CONTROL_PASS name={entry["scenario"]} detections={int(bool(entry["expected"]))}\s*$'
            compile_extra=['+incdir+'+str(src)];sim_extra=[];do='run -all; '
        elif entry['kind'] in ('functional','fault'):
            selected=[next(c for c in inventory['functional_cases'] if c['name']==n) for n in entry['cases']]
            fields=['name','src','dst','length','order','csr_order','expected_error','read_error_burst','read_error_beat','write_error_burst','commit_error','reset_kind','malformed','csr_tests','chain']
            rows=[' '.join(format(c[k],'x') if k in ('src','dst','length') else str(c[k]) for k in fields) for c in selected]
            casefile=wd/'cases.txt';casefile.write_bytes(('\n'.join(rows)+'\n').encode());s['case_input_sha256']=digest(casefile)
            files=[src/'dma_bus.sv',*[source/p for p in lock['files']],src/'dma_adapter.sv',src/'dma_assertions.sv',src/'dma_uvm_pkg.sv',src/'dma_uvm_top.sv'];top='dma_uvm_top'
            compile_extra=['-L',str(a.uvm_lib),'+incdir+'+str(a.uvm_include),'+incdir+'+str(src)];sim_extra=['-L',str(a.uvm_lib)]
            plus=['+CASES='+str(casefile)]+(['+EXPECT_SVA='+entry['expected']] if entry.get('expected') else [])
            if entry['kind']=='fault' and entry['fault']!='missing_marker':plus+=['+FAULT='+entry['fault']]
            marker=rf'^# DMA_UVM_PASS cases={len(selected)} assertions={int(bool(entry.get("expected")))} seed=0x28A6BEEF\s*$'
            if entry.get('fault')=='missing_marker':marker=r'^# DMA_INTENTIONALLY_MISSING_REQUIRED_MARKER$'
            do='vcd file capture.vcd; vcd add /dma_uvm_top/bus/*; run -all; vcd flush; '
        else:
            s.update(status='NOT RUN',reason='UNIMPLEMENTED_REQUIRED_STEP');save();continue
        commands=[[tool(a.sim_bin,'vlib'),'work'],[tool(a.sim_bin,'vlog'),'-sv','-work','work',*compile_extra,*files],
          [tool(a.sim_bin,'vsim'),'-c','-onfinish','exit','-voptargs=+acc','-sv_seed','682016495',*sim_extra,'work.'+top,*plus,'-do','onerror {quit -force -code 1}; '+do+'quit -force -code 0']]
        for i,cmd in enumerate(commands):
            c,text=invoke(cmd,wd,wd/f'{i}.log');s['commands'].append(c)
            reason=failure(c,text,marker if i==2 else None)
            if reason:s.update(status='FAIL',reason=reason);break
        else:
            found=re.findall(r'^# DMA_SVA_DETECTED (\w+) time=',text,re.M)
            expected=[entry['expected']] if entry['expected'] else []
            s.update(status='PASS' if found==expected else 'FAIL',reason='EXECUTED' if found==expected else 'WRONG_DETECTION',expected=expected,observed=found)
            if entry['kind']=='functional' and s['status']=='PASS':
                try:
                    starts=re.findall(r'^# DMA_CASE_START name=(\w+) time=',text,re.M);passes=re.findall(r'^# DMA_CASE_PASS name=(\w+) ',text,re.M)
                    assert starts==passes==entry['cases'],'Functional inventory mismatch'
                    s['cases']=[]
                    for case in selected:
                        row=json.loads((wd/('case-'+case['name']+'.json')).read_text());validate(case,row);s['cases'].append(row)
                    capture=wd/'capture.vcd';assert capture.is_file() and capture.stat().st_size,'Missing VCD'
                    s['capture_sha256']=digest(capture)
                except (OSError,ValueError,KeyError,AssertionError) as error:s.update(status='FAIL',reason='RESULT_ACCOUNTING: '+str(error))
        save();print(s['name'],s['status'],s.get('reason'),flush=True)
    if not a.select:
        passed_cases={(s['name'],c['name']) for s in report['suites'] if s['status']=='PASS' for c in s.get('cases',[])}
        report['functional_case_inventory_matched']={n for _,n in passed_cases}=={c['name'] for c in inventory['functional_cases']}
        for s in report['suites']:
            control=s.get('passing_control',{})
            if s['kind']=='fault' and (control.get('substep'),control.get('case')) not in passed_cases:
                s.update(status='FAIL',reason='PASSING_CONTROL_NOT_EXECUTED')
    report['aggregate_exit_code']=int(len(report['suites'])!=len(steps) or any(s['status']!='PASS' for s in report['suites']) or report.get('functional_case_inventory_matched') is False)
    report['milestone_pass']=not a.select and not a.raw_fault and report['aggregate_exit_code']==0
    report['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
    return report['aggregate_exit_code']
if __name__=='__main__':raise SystemExit(main())
