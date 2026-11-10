#!/usr/bin/env python3
"""Serial deterministic cache milestone. Separate from all published releases."""
import argparse,datetime,json,os,re,sys,time
from pathlib import Path
from advanced_sim import digest,failure,git,run,tool
from cache_program import build,serialize,counts
from cache_mutations import prepare

def qualify_fault(entry,outer,result,log,report,lock):
 """A diagnostic is proof only with successful tools and exact identities."""
 assert outer['exit_code']==result['aggregate_exit_code']==1 and not outer['timed_out']
 assert result['source_revision']==report['source_revision'] and result['input_sha256']==report['input_sha256']
 assert result['environment_clean_after_execution'] and result['raw_fault']
 assert result['source_lock']['observed_revision']==lock['revision'] and result['source_lock']['clean_after_execution']
 assert len(result['suites'])==1
 child=result['suites'][0]
 assert child['name']==entry['name'] and child['status']=='FAIL' and len(child['commands'])==3
 assert all(c['exit_code']==0 and not c['timed_out'] for c in child['commands'])
 assert not re.search(r'\*\* (?:Error|Fatal)|^# UVM_ERROR .*?@|CACHE_PROGRESS_TIMEOUT|CACHE_SVA_DETECTED',log,re.M)
 fatals=re.findall(r'^# UVM_FATAL .*?\[(\w+)\]',log,re.M)
 if entry['fault']=='missing_marker':
  assert not fatals and child['reason']=='MISSING_RESULT_MARKER'
  assert re.findall(r'^# CACHE_UVM_PASS cases=(\d+) assertions=0 seed=0x28A6BEEF\s*$',log,re.M)==['1']
 else:
  assert fatals==[entry['expected_fatal']] and child['reason']=='PROCESS_OR_SIMULATOR_ERROR'
  assert 'CACHE_UVM_PASS' not in log
  m=child['mutation'];assert m['kind']==entry['mutation'] and m['source_revision']==lock['revision']
  assert m['locked_sha256']==lock['sha256']['rtl/design.sv'] and m['compiled_sha256']!=m['locked_sha256'] and not m['checkout_modified']
 return dict(status='PASS',reason='EXPECTED_CHILD_FAILURE',observed_fatals=fatals,child_result=result)

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--output',type=Path,required=True);ap.add_argument('--expected-env-sha')
 ap.add_argument('--select',nargs='+');ap.add_argument('--raw-fault',action='store_true')
 ap.add_argument('--source-cache',type=Path,help=argparse.SUPPRESS)
 ap.add_argument('--sim-bin',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/win64'))
 ap.add_argument('--uvm-lib',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/uvm-1.2'))
 ap.add_argument('--uvm-include',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src'))
 ap.add_argument('--timeout',type=int,default=90);ap.add_argument('--global-timeout',type=int,default=3600)
 a=ap.parse_args();repo=Path(__file__).resolve().parent.parent;src=repo/'verification/cache_uvm'
 if a.output.exists() or min(a.timeout,a.global_timeout)<1:ap.error('Fresh output and positive bounds required')
 if a.raw_fault and (not a.select or len(a.select)!=1):ap.error('Raw fault requires one selected case')
 out=a.output.resolve();out.mkdir(parents=True)
 inventory=json.loads((src/'inventory.json').read_text());lock=json.loads((src/'sources.json').read_text());allsteps=inventory['required_substeps']
 names=[s['name'] for s in allsteps];assert len(names)==len(set(names)) and names
 if a.select and (len(a.select)!=len(set(a.select)) or any(n not in names for n in a.select)):ap.error('Invalid selection')
 steps=[s for s in allsteps if not a.select or s['name'] in a.select]
 if a.raw_fault and steps[0]['kind']!='fault':ap.error('Raw mode requires fault')
 start=time.monotonic()
 report=dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),command=[sys.executable,*sys.argv],source_revision=git(repo,'rev-parse','HEAD'),source_dirty=bool(git(repo,'status','--porcelain')),expected_environment_revision=a.expected_env_sha,serial_execution=True,raw_fault=a.raw_fault,selection=a.select,seed=682016495,seed_hex='0x28A6BEEF',expected_inventory=names,required_selected=[s['name'] for s in steps],suites=[],aggregate_exit_code=1,milestone_pass=False,functional_coverage='NOT RUN',constrained_randomization='NOT RUN',original_advanced_alu_apb='NOT RUN')
 inputs=[*src.glob('*'),Path(__file__),repo/'scripts/advanced_sim.py',repo/'scripts/cache_program.py',repo/'scripts/cache_mutations.py']
 report['input_sha256']={p.relative_to(repo).as_posix():digest(p) for p in inputs if p.is_file()}
 report['runner_revision']=git(repo,'log','-1','--format=%H','--','scripts/run_cache_uvm.py');report['inventory_revision']=git(repo,'log','-1','--format=%H','--','verification/cache_uvm/inventory.json')
 report['configuration']=dict(sim_bin=str(a.sim_bin),uvm_lib=str(a.uvm_lib),uvm_include=str(a.uvm_include),timeout_per_command=a.timeout,global_timeout=a.global_timeout,python_version=sys.version,vendor_input_sha256={str(p):digest(p) for p in [a.uvm_include/'uvm_pkg.sv',a.uvm_include/'uvm_macros.svh',tool(a.sim_bin,'vsim'),tool(a.sim_bin,'vlog')] if p.is_file()})
 def save():(out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 def invoke(cmd,cwd,log,bound=None):return run(cmd,cwd,max(1,min(bound or a.timeout,int(a.global_timeout-(time.monotonic()-start)))),log)
 c,t=invoke([tool(a.sim_bin,'vsim'),'-version'],out,out/'version.log');report['version_command']=c;report['simulator_version']=t.strip();prereq=failure(c,t)
 if report['source_dirty']:prereq='DIRTY_ENVIRONMENT'
 if a.expected_env_sha and (not re.fullmatch('[0-9a-f]{40}',a.expected_env_sha) or a.expected_env_sha!=report['source_revision']):prereq='ENVIRONMENT_SHA_MISMATCH'
 if not a.select and (not a.expected_env_sha or git(repo,'branch','--show-current')):prereq='FULL_RUN_REQUIRES_DETACHED_FULL_SHA'
 source=out/'source'
 if any(s['kind'] in ('functional','fault','portable') for s in steps):
  url=f'https://github.com/{lock["owner"]}/{lock["repository"]}.git';supplier=url
  if a.source_cache:
   assert a.raw_fault and git(a.source_cache,'rev-parse','HEAD')==lock['revision'] and not git(a.source_cache,'status','--porcelain')
   assert git(a.source_cache,'remote','get-url','origin')==url;supplier=str(a.source_cache)
  report['source_lock']=dict(lock,supplier=supplier,commands=[])
  for cmd in [['git','clone','--quiet','--no-hardlinks','--config','core.autocrlf=false','--config','core.longpaths=true',supplier,str(source)],['git','-C',str(source),'checkout','--quiet','--detach',lock['revision']],['git','-C',str(source),'remote','set-url','origin',url]]:
   c,t=invoke(cmd,out,out/f'source-{len(report["source_lock"]["commands"])}.log');report['source_lock']['commands'].append(c)
   if failure(c,t):prereq=prereq or failure(c,t);break
  else:
   report['source_lock'].update(observed_revision=git(source,'rev-parse','HEAD'),clean=not bool(git(source,'status','--porcelain')),execution_files_sha256={p:digest(source/p) for p in lock['execution_files']})
   if report['source_lock']['observed_revision']!=lock['revision'] or not report['source_lock']['clean'] or report['source_lock']['execution_files_sha256']!=lock['execution_sha256']:prereq='DUT_SOURCE_MISMATCH'
 save()
 for entry in steps:
  wd=out/entry['name'];wd.mkdir();s=dict(name=entry['name'],kind=entry['kind'],status='NOT RUN',commands=[]);report['suites'].append(s)
  if prereq or time.monotonic()-start>=a.global_timeout:s['reason']=prereq or 'GLOBAL_TIMEOUT';save();continue
  try:
   if entry['kind']=='portable':
    os.environ['MODELSIM_BIN']='C:/intelFPGA/20.1/modelsim_ase/win32aloem'
    cmd=[sys.executable,str(source/'scripts/run_contract.py'),'--output-dir',str(wd/'run')]
    c,t=invoke(cmd,source,wd/'wrapper.log',600);s['commands'].append(c)
    assert not failure(c,t),'Portable wrapper failed'
    r=json.loads((wd/'run/results.json').read_text());assert r['overall']=='PASS' and r['source_revision']==lock['revision'] and not r['source_dirty']
    assert [x['checks'] for x in r['simulations']]==[7,1639] and all(x['status']=='PASS' and x['simulator_exit_code']==0 for x in r['simulations'])
    assert re.findall(r'^PASS (\w+) checks=(\d+)\s*$',t,re.M)==[('tb_cache_2way','7'),('cache_contract_test','1639')]
    s.update(status='PASS',reason='EXECUTED',result=r)
   elif entry['kind']=='fault' and not a.raw_fault:
    cmd=[sys.executable,str(Path(__file__)),'--output',str(wd/'child'),'--select',entry['name'],'--raw-fault','--source-cache',str(source),'--sim-bin',str(a.sim_bin),'--uvm-lib',str(a.uvm_lib),'--uvm-include',str(a.uvm_include),'--timeout',str(a.timeout),'--expected-env-sha',report['source_revision']]
    c,t=invoke(cmd,repo,wd/'child-wrapper.log',6*a.timeout);s['commands'].append(c);s['child_wrapper_exit']=c['exit_code'];s['passing_control']=entry['passing_control']
    r=json.loads((wd/'child/results.json').read_text());log=(wd/'child'/entry['name']/'2.log').read_text()
    s.update(qualify_fault(entry,c,r,log,report,lock))
   else:
    compile_extra=[];sim_extra=[];do='run -all; '
    if entry['kind']=='sva':
     files=[src/'cache_bus.sv',src/'cache_assertions.sv',src/'cache_sva_control.sv'];top='cache_sva_control'
     plus=['+SCENARIO='+entry['scenario']]+(['+EXPECT_SVA='+entry['expected']] if entry['expected'] else [])
     marker=rf'^# CACHE_SVA_CONTROL_PASS name={entry["scenario"]} detections={int(bool(entry["expected"]))}\s*$'
    else:
     plans=[build(n) for n in entry['cases']];(wd/'program.txt').write_text(serialize(plans),encoding='utf-8',newline='\n')
     s['program_sha256']=digest(wd/'program.txt');s['planned_counts']=counts(plans)
     rtl=source/'rtl/design.sv'
     if entry.get('mutation'):rtl,s['mutation']=prepare(rtl,wd/'disposable-rtl',entry['mutation'],lock['revision'])
     files=[src/'cache_bus.sv',rtl,src/'cache_assertions.sv',src/'cache_uvm_pkg.sv',src/'cache_uvm_top.sv'];top='cache_uvm_top'
     compile_extra=['-L',str(a.uvm_lib),'+incdir+'+str(a.uvm_include)];sim_extra=['-L',str(a.uvm_lib)]
     plus=['+PROGRAM='+str(wd/'program.txt')];marker=rf'^# CACHE_UVM_PASS cases={len(plans)} assertions=0 seed=0x28A6BEEF\s*$'
     if entry.get('fault')=='missing_marker':marker=r'^# CACHE_INTENTIONALLY_MISSING_REQUIRED_MARKER$'
     do='vcd file capture.vcd; vcd add /cache_uvm_top/bus/*; run -all; vcd flush; '
    commands=[[tool(a.sim_bin,'vlib'),'work'],[tool(a.sim_bin,'vlog'),'-sv','-work','work',*compile_extra,*files],[tool(a.sim_bin,'vsim'),'-c','-onfinish','exit','-voptargs=+acc','-sv_seed','682016495',*sim_extra,'work.'+top,*plus,'-do','onerror {quit -force -code 1}; '+do+'quit -force -code 0']]
    for i,cmd in enumerate(commands):
     c,t=invoke(cmd,wd,wd/f'{i}.log');s['commands'].append(c)
     reason=failure(c,t,marker if i==2 else None)
     if reason:s.update(status='FAIL',reason=reason);break
    else:
     found=re.findall(r'^# CACHE_SVA_DETECTED (\w+) time=',t,re.M)
     assert found==([entry['expected']] if entry['kind']=='sva' and entry['expected'] else []),'Wrong SVA detection'
     s.update(status='PASS',reason='EXECUTED',observed_sva=found)
     if entry['kind']!='sva':
      s['uvm_runtime_versions']=sorted(set(re.findall(r'\[Questa UVM\] (QUESTA_UVM-[\d.]+)',t)));assert s['uvm_runtime_versions']==['QUESTA_UVM-1.2.3']
      assert re.findall(r'^# CACHE_CASE_START name=(\w+) time=',t,re.M)==entry['cases']
      assert re.findall(r'^# CACHE_CASE_PASS name=(\w+) ',t,re.M)==entry['cases']
      s['cases']=[]
      for n in entry['cases']:
       row=json.loads((wd/f'case-{n}.json').read_text());assert row['name']==n
       assert {k:v for k,v in row.items() if k!='name'}==s['planned_counts'][n],(n,row,s['planned_counts'][n])
       assert row['lookups']==row['observations']==row['hits']+row['misses'] and row['comparisons']==2*row['observations']
       s['cases'].append(row)
      assert (wd/'capture.vcd').stat().st_size;s['capture_sha256']=digest(wd/'capture.vcd')
  except (OSError,ValueError,KeyError,IndexError,TypeError,AssertionError) as e:s.update(status='FAIL',reason='QUALIFICATION_OR_ACCOUNTING',detail=str(e))
  save();print(s['name'],s['status'],s.get('reason'),flush=True)
 if not a.select:
  passed={(s['name'],c['name']) for s in report['suites'] if s['status']=='PASS' for c in s.get('cases',[])}
  report['functional_inventory_matched']={n for _,n in passed}=={c['name'] for c in inventory['functional_cases']}
  for s in report['suites']:
   if s['kind']=='fault' and (s.get('passing_control',{}).get('substep'),s.get('passing_control',{}).get('case')) not in passed:s.update(status='FAIL',reason='PASSING_CONTROL_NOT_EXECUTED')
 report['aggregate_exit_code']=int(any(s['status']!='PASS' for s in report['suites']) or len(report['suites'])!=len(steps) or report.get('functional_inventory_matched') is False)
 if 'source_lock' in report and 'observed_revision' in report['source_lock']:
  report['source_lock']['clean_after_execution']=not bool(git(source,'status','--porcelain')) and all(digest(source/p)==h for p,h in lock['execution_sha256'].items())
  if not report['source_lock']['clean_after_execution']:report['aggregate_exit_code']=1
 report['environment_clean_after_execution']=git(repo,'rev-parse','HEAD')==report['source_revision'] and not git(repo,'status','--porcelain') and all(digest(repo/p)==h for p,h in report['input_sha256'].items())
 if not report['environment_clean_after_execution']:report['aggregate_exit_code']=1
 report['milestone_pass']=not a.select and not a.raw_fault and report['aggregate_exit_code']==0
 report['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save();return report['aggregate_exit_code']
if __name__=='__main__':raise SystemExit(main())
