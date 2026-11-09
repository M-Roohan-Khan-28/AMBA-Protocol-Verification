#!/usr/bin/env python3
"""Separate deterministic AHB milestone; inventory-driven, serial and fail closed."""
import argparse,datetime,json,re,sys,time,os
from pathlib import Path
from advanced_sim import digest,failure,git,run,tool
from ahb_program import build,serialize
from ahb_mutations import prepare as prepare_mutation

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output',type=Path,required=True)
    ap.add_argument('--select',nargs='+',help='Diagnostic selection; never a complete milestone pass')
    ap.add_argument('--sim-bin',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/win64'))
    ap.add_argument('--uvm-lib',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/uvm-1.2'))
    ap.add_argument('--uvm-include',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src'))
    ap.add_argument('--timeout',type=int,default=90)
    ap.add_argument('--global-timeout',type=int,default=3600)
    ap.add_argument('--expected-env-sha',help='Full environment SHA required for a full release run')
    ap.add_argument('--raw-fault',action='store_true',help='Internal diagnostic child: preserve the genuine nonzero fault result')
    ap.add_argument('--source-cache',type=Path,help=argparse.SUPPRESS)
    ap.add_argument('--dut-mirror',type=Path,help='Optional clean local DUT mirror at the exact lock; transport is recorded')
    a=ap.parse_args();repo=Path(__file__).resolve().parent.parent;src=repo/'verification/ahb_uvm'
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
    report['input_sha256']={p.relative_to(repo).as_posix():digest(p) for p in [*src.glob('*'),Path(__file__),repo/'scripts/advanced_sim.py',repo/'scripts/ahb_program.py',repo/'scripts/ahb_mutations.py'] if p.is_file()}
    report['expected_environment_revision']=a.expected_env_sha
    report['runner_revision']=git(repo,'log','-1','--format=%H','--','scripts/run_ahb_uvm.py')
    report['inventory_revision']=git(repo,'log','-1','--format=%H','--','verification/ahb_uvm/inventory.json')
    report['configuration']={'sim_bin':str(a.sim_bin),'uvm_lib':str(a.uvm_lib),'uvm_include':str(a.uvm_include),
      'timeout_per_command':a.timeout,'global_timeout':a.global_timeout,'python_version':sys.version,
      'vendor_input_sha256':{str(p):digest(p) for p in [a.uvm_include/'uvm_pkg.sv',a.uvm_include/'uvm_macros.svh',tool(a.sim_bin,'vsim'),tool(a.sim_bin,'vlog')] if p.is_file()}}
    start=time.monotonic()
    def save():(out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    def invoke(cmd,cwd,log):return run(cmd,cwd,max(1,min(a.timeout,int(a.global_timeout-(time.monotonic()-start)))),log)
    v,t=invoke([tool(a.sim_bin,'vsim'),'-version'],out,out/'version.log');report['version_command']=v;report['simulator_version']=t.strip()
    prereq=failure(v,t)
    if report['source_dirty']:prereq='ENVIRONMENT_SOURCE_MISMATCH'
    if a.expected_env_sha and (len(a.expected_env_sha)!=40 or a.expected_env_sha!=report['source_revision'] or report['source_dirty']):prereq='ENVIRONMENT_SOURCE_MISMATCH'
    if not a.select and not a.expected_env_sha:prereq='FULL_RUN_REQUIRES_ENVIRONMENT_SHA'
    source=out/'source';lock=json.loads((src/'sources.json').read_text())
    if any(s['kind'] in ('functional','fault','portable') for s in steps):
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
            if report['source_lock']['rtl_sha256']!=lock['sha256']:prereq='DUT_BYTE_MISMATCH'
            report['source_lock']['execution_files_sha256']={p:digest(source/p) for p in lock['execution_files']}
    for entry in steps:
        wd=out/entry['name'];wd.mkdir();s=dict(name=entry['name'],kind=entry['kind'],status='NOT RUN',commands=[]);report['suites'].append(s)
        if prereq or time.monotonic()-start>=a.global_timeout:s['reason']=prereq or 'GLOBAL_TIMEOUT';save();continue
        if entry['kind']=='portable':
            os.environ['MODELSIM_BIN']='C:/intelFPGA/20.1/modelsim_ase/win32aloem'
            cmd=['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(source/'scripts/run_regression.ps1'),'-OutputDir',str(wd/'run')]
            c,text=run(cmd,source,min(600,a.global_timeout-(time.monotonic()-start)),wd/'portable-wrapper.log');s['commands'].append(c)
            s.update(status='FAIL',reason=failure(c,text,r'^AHB16_REGRESSION_PASS checks=924 negatives=3 output=') or 'PORTABLE_ACCOUNTING')
            try:
                result=json.loads((wd/'run/results.json').read_text())
                assert not failure(c,text,r'^AHB16_REGRESSION_PASS checks=924 negatives=3 output=')
                assert result['overall']=='PASS' and result['source_revision']==lock['revision'] and not result['source_dirty']
                assert len(result['simulations'])==2 and all(x['status']=='PASS' and x['simulator_exit_code']==0 for x in result['simulations'])
                s.update(status='PASS',reason='EXECUTED',result=result)
            except (OSError,ValueError,KeyError,AssertionError) as error:s['detail']=str(error)
            save();print(s['name'],s['status'],s['reason'],flush=True);continue
        if entry['kind']=='fault' and not a.raw_fault:
            child=wd/'child'
            cmd=[sys.executable,str(Path(__file__)),'--select',entry['name'],'--raw-fault','--output',str(child),'--sim-bin',str(a.sim_bin),'--uvm-lib',str(a.uvm_lib),'--uvm-include',str(a.uvm_include),'--timeout',str(a.timeout),'--source-cache',str(source)]
            if a.expected_env_sha:cmd+=['--expected-env-sha',a.expected_env_sha]
            c,text=run(cmd,repo,max(1,min(6*a.timeout,int(a.global_timeout-(time.monotonic()-start)))),wd/'child-wrapper.log');s['commands'].append(c)
            s.update(status='FAIL',reason='FAULT_NOT_QUALIFIED',child_wrapper_exit=c['exit_code'],passing_control=entry['passing_control'])
            try:
                result=json.loads((child/'results.json').read_text());log=(child/entry['name']/'2.log').read_text();cs=result['suites'][0]
                assert c['exit_code']==result['aggregate_exit_code']==1 and not c['timed_out']
                assert result['source_revision']==report['source_revision'] and result['input_sha256']==report['input_sha256']
                assert result['source_lock']['observed_revision']==lock['revision'] and result['source_lock']['clean_after_execution']
                assert len(result['suites'])==1 and len(cs['commands'])==3 and cs['status']=='FAIL'
                assert all(x['exit_code']==0 and not x['timed_out'] for x in cs['commands'][:2])
                assert not cs['commands'][2]['timed_out']
                fatals=re.findall(r'^# UVM_FATAL .*?\[(\w+)\]',log,re.M)
                sva=re.findall(r'^# AHB_SVA_DETECTED (\w+) time=',log,re.M)
                assert not re.search(r'\*\* Error|^# UVM_ERROR .*?@|AHB_PROGRESS_TIMEOUT',log,re.M)
                expected=entry['expected_fatal']
                if entry['fault']=='missing_marker':
                    assert not fatals and not sva and cs['reason']=='MISSING_RESULT_MARKER'
                    assert re.search(r'^# AHB_UVM_PASS cases=1 assertions=0 seed=0x28A6BEEF\s*$',log,re.M)
                    assert cs['commands'][2]['exit_code']==0 and not re.search(r'\*\* Fatal',log)
                elif expected.startswith('SVA:'):
                    ident=expected.split(':')[1]
                    assert sva==[ident] and not fatals
                    assert re.findall(r'\*\* Fatal: AHB_SVA_UNEXPECTED (\w+)',log)==[ident]
                    assert len(re.findall(r'\*\* Fatal:',log))==1 and cs['reason']=='PROCESS_OR_SIMULATOR_ERROR'
                else:
                    assert fatals==[expected] and not sva and not re.search(r'\*\* Fatal',log)
                    assert cs['commands'][2]['exit_code']==0 and cs['reason']=='PROCESS_OR_SIMULATOR_ERROR'
                    assert 'AHB_UVM_PASS' not in log
                if entry.get('mutation'):
                    m=cs['mutation'];assert m['kind']==entry['mutation'] and m['source_revision']==lock['revision']
                    assert m['locked_sha256']==lock['sha256']['rtl/design.sv'] and m['compiled_sha256']!=m['locked_sha256'] and not m['checkout_modified']
                s.update(status='PASS',reason='EXPECTED_CHILD_FAILURE',expected_fatal=expected,observed_fatals=fatals,observed_sva=sva,child_result=result)
            except (OSError,ValueError,KeyError,AssertionError) as error:s['detail']=str(error)
            save();print(s['name'],s['status'],s['reason'],'child exit',c['exit_code'],flush=True);continue
        compile_extra=[];sim_extra=[];do='run -all; '
        if entry['kind']=='sva':
            files=[src/'ahb_bus.sv',src/'ahb_assertions.sv',src/'ahb_sva_control.sv'];top='ahb_sva_control'
            plus=['+SCENARIO='+entry['scenario']]+(['+EXPECT_SVA='+entry['expected']] if entry['expected'] else [])
            marker=rf'^# AHB_SVA_CONTROL_PASS name={entry["scenario"]} detections={int(bool(entry["expected"]))}\s*$'
        else:
            compile_extra=['-L',str(a.uvm_lib),'+incdir+'+str(a.uvm_include)]
            sim_extra=['-L',str(a.uvm_lib)]
            if entry['kind']=='checker':
                files=[src/'ahb_bus.sv',src/'ahb_uvm_pkg.sv',src/'ahb_checker_control.sv'];top='ahb_checker_control'
                plus=['+SCENARIO='+entry['scenario']];marker=rf'^# AHB_CHECKER_PASS name={entry["scenario"]}\s*$'
            else:
                plans=[build(next(c for c in inventory['functional_cases'] if c['name']==n)) for n in entry['cases']]
                original=serialize(plans);program=original
                if entry.get('fault')=='duplicate':
                    # Same legal write and data, no second request intention. Never alter expected memory.
                    row=[1,2,1,2,0,0,1,1,0,0,0,0,0,0]
                    retire=[0,0,0,2,0,0x1265abcd,1,1,0,0,0,0,0,0]
                    extra=''.join('smoke 0 '+' '.join(map(str,r))+'\n' for r in (row,retire))
                    program=original.replace('smoke 2 ',extra+'smoke 2 ')
                (wd/'program-original.txt').write_bytes(original.encode());(wd/'program.txt').write_bytes(program.encode())
                s['program_sha256']=digest(wd/'program.txt');s['original_program_sha256']=digest(wd/'program-original.txt')
                s['planned_counts']={p.name:p.counts for p in plans}
                rtl=source/'rtl/design.sv'
                if entry.get('mutation'):rtl,s['mutation']=prepare_mutation(rtl,wd/'disposable-rtl',entry['mutation'],lock['revision'])
                files=[src/'ahb_bus.sv',rtl,src/'ahb_assertions.sv',src/'ahb_uvm_pkg.sv',src/'ahb_uvm_top.sv'];top='ahb_uvm_top'
                plus=['+PROGRAM='+str(wd/'program.txt')]
                if entry.get('fault') in ('address_alias','omit_observation'):plus+=['+FAULT='+entry['fault']]
                marker=rf'^# AHB_UVM_PASS cases={len(plans)} assertions=0 seed=0x28A6BEEF\s*$'
                if entry.get('fault')=='missing_marker':marker=r'^# AHB_INTENTIONALLY_MISSING_REQUIRED_MARKER$'
                do='vcd file capture.vcd; vcd add /ahb_uvm_top/bus/*; run -all; vcd flush; '
        commands=[[tool(a.sim_bin,'vlib'),'work'],[tool(a.sim_bin,'vlog'),'-sv','-work','work',*compile_extra,*files],
          [tool(a.sim_bin,'vsim'),'-c','-onfinish','exit','-voptargs=+acc','-sv_seed','682016495',*sim_extra,'work.'+top,*plus,'-do','onerror {quit -force -code 1}; '+do+'quit -force -code 0']]
        qualified=False
        for i,cmd in enumerate(commands):
            c,text=invoke(cmd,wd,wd/f'{i}.log');s['commands'].append(c)
            if i==2:
                versions=re.findall(r'\[Questa UVM\] (QUESTA_UVM-[\d.]+)',text)
                if versions:s['uvm_runtime_versions']=sorted(set(versions))
            reason=failure(c,text,marker if i==2 else None)
            if i==2 and entry['kind']=='checker' and entry['expected']:
                fatals=re.findall(r'^# UVM_FATAL .*?\[(\w+)\]',text,re.M)
                qualified=(c['exit_code']==0 and not c['timed_out'] and fatals==[entry['expected']] and not re.search(r'\*\* (?:Error|Fatal)|^# UVM_ERROR .*?@',text,re.M) and f'AHB_CHECKER_START name={entry["scenario"]}' in text and 'AHB_CHECKER_PASS' not in text)
                s['observed_fatals']=fatals
                reason=None if qualified else 'WRONG_CHECKER_DETECTION'
            if reason:s.update(status='FAIL',reason=reason);break
        else:
            found=re.findall(r'^# AHB_SVA_DETECTED (\w+) time=',text,re.M)
            expected=[entry['expected']] if entry['kind']=='sva' and entry['expected'] else []
            s.update(status='PASS' if found==expected else 'FAIL',reason='EXPECTED_CHECKER_DETECTION' if qualified else 'EXECUTED',expected=expected,observed=found)
            if found!=expected:s['reason']='WRONG_SVA_DETECTION'
            if entry['kind'] in ('functional','fault') and s['status']=='PASS':
                try:
                    starts=re.findall(r'^# AHB_CASE_START name=(\w+) time=',text,re.M);passes=re.findall(r'^# AHB_CASE_PASS name=(\w+) ',text,re.M)
                    assert starts==passes==entry['cases'],'Functional inventory mismatch'
                    s['cases']=[]
                    for p in plans:
                        row=json.loads((wd/('case-'+p.name+'.json')).read_text())
                        assert row['name']==p.name and row['comparisons']>0
                        for k,v in p.counts.items():assert row[k]==v,(p.name,k,v,row[k])
                        assert row['offered']==row['accepted']+row['withdrawn']+row['reset_offered']
                        assert row['accepted']==row['success']+row['errors']+row['reset_accepted']
                        assert row['success']==row['writes']+row['reads']
                        s['cases'].append(row)
                    capture=wd/'capture.vcd';assert capture.is_file() and capture.stat().st_size
                    s['capture_sha256']=digest(capture)
                except (OSError,ValueError,KeyError,AssertionError) as error:s.update(status='FAIL',reason='RESULT_ACCOUNTING: '+str(error))
        save();print(s['name'],s['status'],s.get('reason'),flush=True)
    if not a.select:
        passed_cases={(s['name'],c['name']) for s in report['suites'] if s['status']=='PASS' for c in s.get('cases',[])}
        report['functional_case_inventory_matched']={n for _,n in passed_cases}=={c['name'] for c in inventory['functional_cases']}
        for s in report['suites']:
            control=s.get('passing_control',{})
            if s['kind']=='fault' and (control.get('substep'),control.get('case')) not in passed_cases:s.update(status='FAIL',reason='PASSING_CONTROL_NOT_EXECUTED')
    report['aggregate_exit_code']=int(len(report['suites'])!=len(steps) or any(s['status']!='PASS' for s in report['suites']) or report.get('functional_case_inventory_matched') is False)
    if 'source_lock' in report and 'observed_revision' in report['source_lock']:
        report['source_lock']['clean_after_execution']=not bool(git(source,'status','--porcelain')) and all(digest(source/p)==h for p,h in report['source_lock']['execution_files_sha256'].items())
        if not report['source_lock']['clean_after_execution']:report['aggregate_exit_code']=1
    report['environment_clean_after_execution']=(git(repo,'rev-parse','HEAD')==report['source_revision'] and not git(repo,'status','--porcelain') and all(digest(repo/p)==h for p,h in report['input_sha256'].items()))
    if not report['environment_clean_after_execution']:report['aggregate_exit_code']=1
    report['uvm_runtime_versions']=sorted({v for s in report['suites'] for v in s.get('uvm_runtime_versions',[])})
    report['milestone_pass']=not a.select and not a.raw_fault and report['aggregate_exit_code']==0
    report['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save()
    return report['aggregate_exit_code']
if __name__=='__main__':raise SystemExit(main())
