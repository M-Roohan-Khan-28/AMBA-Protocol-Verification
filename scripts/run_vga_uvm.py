#!/usr/bin/env python3
"""Strict separate deterministic VGA milestone; serial tools, immutable locks."""
import argparse,datetime,json,os,re,sys,time,uuid
from pathlib import Path
from advanced_sim import run,failure,digest,git,tool
from vga_mutations import prepare,TRANSFORMS

def qualify_fault(entry,outer,result,log,report,lock,nonce,expected_mutation=None):
 assert outer['exit_code']==1 and not outer['timed_out']
 assert result['aggregate_exit_code']==1 and not result['milestone_pass'] and result['raw_fault']
 assert result['run_id']==nonce and result['source_revision']==result['expected_environment_revision']==report['source_revision']
 assert result['input_sha256']==report['input_sha256'] and not result['source_dirty'] and result['environment_clean_after_execution']
 assert result['required_selected']==result['selection']==[entry['name']]
 assert result['source_lock']['observed_revision']==lock['revision'] and result['source_lock']['clean_after_execution']
 assert result['source_lock']['execution_files_sha256']==lock['execution_sha256']
 assert len(result['suites'])==1
 child=result['suites'][0];assert child['name']==entry['name'] and child['status']=='FAIL'
 assert len(child['commands'])==3 and [Path(c['command'][0]).stem.lower() for c in child['commands']]==['vlib','vlog','vsim']
 assert all(c['exit_code']==0 and not c['timed_out'] for c in child['commands'])
 argv=[c['command'] for c in child['commands']]
 assert argv[0][1:]==['work'] and '-sv' in argv[1] and '-work' in argv[1]
 assert any(str(p).endswith('vga_uvm_top.sv') for p in argv[1])
 assert '-c' in argv[2] and 'work.vga_uvm_top' in argv[2] and '+RUN_ID='+nonce in argv[2] and '+GROUP='+entry['group'] in argv[2]
 assert argv[2][-2:]==['-do','onerror {quit -force -code 1}; run -all; quit -force -code 0']
 assert re.findall(r'^# VGA_RUN_ID (\S+)\s*$',log,re.M)==[nonce]
 assert not re.search(r'\*\*\s+(?:Error|Fatal)\b|^# UVM_ERROR .*?@|VGA_PROGRESS_TIMEOUT',log,re.M)
 fatals=re.findall(r'^# UVM_FATAL .*?\[(\w+)\]',log,re.M)
 sva=re.findall(r'^# VGA_SVA_DETECTED (\w+) time=',log,re.M)
 assert sorted(sva)==sorted(entry['expected_sva'])
 if entry['fault']=='missing_marker':
  assert not fatals and child['reason']=='MISSING_RESULT_MARKER'
  assert len(re.findall(r'^# VGA_UVM_PASS cases=1 observations=\d+ comparisons=\d+ assertions=0 seed=0x28A6BEEF\s*$',log,re.M))==1
 else:
  assert fatals==[entry['expected_fatal']] and child['reason']=='PROCESS_OR_SIMULATOR_ERROR'
  assert 'VGA_UVM_PASS' not in log
 if entry['fault'] in TRANSFORMS:
  assert child['mutation']==expected_mutation
  assert expected_mutation['source_revision']==lock['revision'] and expected_mutation['locked_sha256']==lock['execution_sha256']['rtl/design.sv']
  assert expected_mutation['compiled_sha256']!=expected_mutation['locked_sha256'] and not expected_mutation['checkout_modified']
 return dict(status='PASS',reason='EXPECTED_CHILD_FAILURE',observed_fatals=fatals,observed_sva=sva,child_result=result)

def validate_functional(result,entry,wd,log):
 assert re.findall(r'^# VGA_CASE_START name=(\w+) time=',log,re.M)==entry['cases']
 assert re.findall(r'^# VGA_CASE_PASS name=(\w+) ',log,re.M)==entry['cases']
 assert not re.findall(r'^# VGA_SVA_DETECTED ',log,re.M)
 rows=[]
 for name in entry['cases']:
  row=json.loads((wd/f'case-{name}.json').read_bytes());assert row['name']==name
  assert row['observations']==row['clocks']+row['control_only']+row['initial_samples']
  assert row['comparisons']==6*row['observations'] and row['enabled_writes']==row['valid_writes']+row['ignored_writes']
  assert row['reset_writes']<=row['valid_writes']+row['ignored_writes']
  rows.append(row)
 totals=json.loads((wd/'totals.json').read_bytes())
 assert totals['cases']==len(rows)
 for key,source in [('observations','observations'),('comparisons','comparisons'),('clocks','clocks'),('writes','valid_writes'),('ignored','ignored_writes'),('frames','complete_frames')]:assert totals[key]==sum(r[source] for r in rows),(key,totals,rows)
 if entry['group']=='functional':
  byname={r['name']:r for r in rows}
  for name in ('pattern_low_scan','pattern_high_scan'):
   row=byname[name];assert row['distinct_addresses']==4800 and row['complete_frames']==1 and row['pixel_samples']==420000 and row['active_samples']==307200 and row['hs_low']==50400 and row['vs_low']==1600
  assert byname['all_rgb332']['distinct_colors']==256
  assert sum(r['complete_frames'] for r in rows[:7])==2
  assert all(n>0 for n in totals['phase_writes'])
  assert all(n>0 for n in byname['divider_phase_writes']['phase_writes'])
  assert totals['frame_pixels']==420000 and (wd/'actual-frame.rgb444').stat().st_size==420000*4
  assert len(re.findall(r'^# VGA_FRAME_CAPTURE_PASS pixels=420000 time=',log,re.M))==1
 return dict(cases=rows,totals=totals)

def main():
 ap=argparse.ArgumentParser(description=__doc__)
 ap.add_argument('--output',type=Path,required=True);ap.add_argument('--expected-env-sha')
 ap.add_argument('--select',nargs='+');ap.add_argument('--raw-fault',action='store_true');ap.add_argument('--run-id')
 ap.add_argument('--source-cache',type=Path,help=argparse.SUPPRESS)
 ap.add_argument('--sim-bin',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/win64'))
 ap.add_argument('--uvm-lib',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/uvm-1.2'))
 ap.add_argument('--uvm-include',type=Path,default=Path('C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src'))
 ap.add_argument('--timeout',type=int,default=180);ap.add_argument('--raster-timeout',type=int,default=900);ap.add_argument('--global-timeout',type=int,default=5400)
 a=ap.parse_args();repo=Path(__file__).resolve().parents[1];src=repo/'verification/vga_uvm'
 if a.output.exists() or min(a.timeout,a.raster_timeout,a.global_timeout)<1:ap.error('Fresh output and positive bounds required')
 inv=json.loads((src/'inventory.json').read_bytes());lock=json.loads((src/'sources.json').read_bytes());entries=inv['required_substeps'];names=[e['name'] for e in entries]
 assert len(names)==len(set(names))
 if a.select and (len(a.select)!=len(set(a.select)) or any(n not in names for n in a.select)):ap.error('Invalid selection')
 steps=[e for e in entries if not a.select or e['name'] in a.select]
 if a.raw_fault and (len(steps)!=1 or steps[0]['kind']!='fault'):ap.error('Raw fault requires one fault entry')
 out=a.output.resolve();out.mkdir(parents=True);start=time.monotonic();nonce=a.run_id or uuid.uuid4().hex
 report=dict(started_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),command=[sys.executable,*sys.argv],run_id=nonce,source_revision=git(repo,'rev-parse','HEAD'),expected_environment_revision=a.expected_env_sha,source_dirty=bool(git(repo,'status','--porcelain')),serial_execution=True,raw_fault=a.raw_fault,selection=a.select,seed=682016495,seed_hex='0x28A6BEEF',expected_inventory=names,required_selected=[s['name'] for s in steps],suites=[],aggregate_exit_code=1,milestone_pass=False,functional_coverage='NOT RUN',constrained_randomization='NOT RUN',original_advanced_alu_apb='NOT RUN')
 inputs=[*src.glob('*'),Path(__file__),repo/'scripts/vga_mutations.py',repo/'scripts/qualify_vga_runner.py',repo/'scripts/advanced_sim.py']
 report['input_sha256']={p.relative_to(repo).as_posix():digest(p) for p in inputs if p.is_file()}
 report['runner_revision']=git(repo,'log','-1','--format=%H','--','scripts/run_vga_uvm.py');report['inventory_revision']=git(repo,'log','-1','--format=%H','--','verification/vga_uvm/inventory.json')
 report['configuration']=dict(sim_bin=str(a.sim_bin),uvm_lib=str(a.uvm_lib),uvm_include=str(a.uvm_include),timeout_per_command=a.timeout,raster_timeout=a.raster_timeout,global_timeout=a.global_timeout,python_version=sys.version,vendor_input_sha256={str(p):digest(p) for p in [a.uvm_include/'uvm_pkg.sv',a.uvm_include/'uvm_macros.svh',tool(a.sim_bin,'vlog'),tool(a.sim_bin,'vsim')] if p.is_file()})
 def save():(out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
 def invoke(cmd,cwd,log,bound=None):return run(cmd,cwd,max(1,min(bound or a.timeout,int(a.global_timeout-(time.monotonic()-start)))),log)
 c,t=invoke([tool(a.sim_bin,'vsim'),'-version'],out,out/'version.log');report['version_command']=c;report['simulator_version']=t.strip();prereq=failure(c,t)
 if report['source_dirty']:prereq='DIRTY_ENVIRONMENT'
 if not a.expected_env_sha or not re.fullmatch('[0-9a-f]{40}',a.expected_env_sha) or a.expected_env_sha!=report['source_revision']:prereq='ENVIRONMENT_SHA_MISMATCH'
 if not a.select and git(repo,'branch','--show-current'):prereq='FULL_RUN_REQUIRES_DETACHED_FULL_SHA'
 source=out/'source'
 if any(s['kind'] in ('functional','fault','portable') for s in steps):
  url=f'https://github.com/{lock["owner"]}/{lock["repository"]}.git';supplier=url
  if a.source_cache:
   assert a.raw_fault and git(a.source_cache,'rev-parse','HEAD')==lock['revision'] and not git(a.source_cache,'status','--porcelain') and git(a.source_cache,'remote','get-url','origin')==url;supplier=str(a.source_cache)
  report['source_lock']=dict(lock,supplier=supplier,commands=[])
  for cmd in [['git','clone','--quiet','--no-hardlinks','--config','core.longpaths=true','--config','core.autocrlf=false',supplier,str(source)],['git','-C',str(source),'checkout','--quiet','--detach',lock['revision']],['git','-C',str(source),'remote','set-url','origin',url]]:
   c,t=invoke(cmd,out,out/f'source-{len(report["source_lock"]["commands"])}.log');report['source_lock']['commands'].append(c)
   if failure(c,t):prereq=prereq or failure(c,t);break
  else:
   report['source_lock'].update(observed_revision=git(source,'rev-parse','HEAD'),clean=not bool(git(source,'status','--porcelain')),execution_files_sha256={p:digest(source/p) for p in lock['execution_files']})
   if report['source_lock']['observed_revision']!=lock['revision'] or not report['source_lock']['clean'] or report['source_lock']['execution_files_sha256']!=lock['execution_sha256']:prereq='DUT_SOURCE_MISMATCH'
 save()
 for e in steps:
  wd=out/e['name'];wd.mkdir();s=dict(name=e['name'],kind=e['kind'],status='NOT RUN',commands=[]);report['suites'].append(s)
  if prereq or time.monotonic()-start>=a.global_timeout:s['reason']=prereq or 'GLOBAL_TIMEOUT';save();continue
  try:
   if e['kind']=='runner':
    c,t=invoke([sys.executable,str(repo/'scripts/qualify_vga_runner.py'),'--output',str(wd/'run')],repo,wd/'qualification.log');s['commands'].append(c)
    assert not failure(c,t,r'^VGA_RUNNER_QUALIFICATION_PASS checks=\d+ failures=0\s*$')
    r=json.loads((wd/'run/results.json').read_bytes());assert r['status']=='PASS' and r['exit_code']==0 and all(x['pass_'] for x in r['cases']) and r['checks']==len(r['cases'])
    assert r['tested_environment']==report['source_revision'] and r['production_sha256']==digest(Path(__file__)) and r['qualification_sha256']==digest(repo/'scripts/qualify_vga_runner.py')
    s.update(status='PASS',reason='SYNTHETIC_RECORD_FIXTURES',result=r)
   elif e['kind']=='portable':
    os.environ['MODELSIM_BIN']='C:/intelFPGA/20.1/modelsim_ase/win32aloem'
    cmd=['powershell.exe','-NoProfile','-ExecutionPolicy','Bypass','-File',str(source/'scripts/run_regression.ps1'),'-OutputDir',str(wd/'run')]
    c,t=invoke(cmd,source,wd/'wrapper.log',600);s['commands'].append(c);assert not failure(c,t)
    r=json.loads((wd/'run/results.json').read_bytes());assert r['overall']=='PASS' and r['source_revision']==lock['revision'] and not r['source_dirty']
    sims=r['simulations'];assert len(sims)==3 and all(x['status']=='PASS' and x['simulator_exit_code']==0 for x in sims)
    assert 'TOTAL PASSED = 7' in (wd/'run/legacy.log').read_text() and 'VGA_RESET_WRITE_EDGE_PASS checks=8 reset_held=1' in sims[1]['marker']
    assert 'VGA_RASTER_PASS checks=29588940 ' in sims[2]['marker']
    assert len(re.findall(r'^VGA_RASTER_REGRESSION_PASS output=',t,re.M))==1
    s.update(status='PASS',reason='EXECUTED',result=r)
   elif e['kind']=='fault' and not a.raw_fault:
    child_nonce=uuid.uuid4().hex
    cmd=[sys.executable,str(Path(__file__)),'--output',str(wd/'child'),'--expected-env-sha',report['source_revision'],'--select',e['name'],'--raw-fault','--run-id',child_nonce,'--source-cache',str(source),'--sim-bin',str(a.sim_bin),'--uvm-lib',str(a.uvm_lib),'--uvm-include',str(a.uvm_include),'--raster-timeout',str(a.raster_timeout)]
    c,t=invoke(cmd,repo,wd/'child-wrapper.log',a.raster_timeout+4*a.timeout);s['commands'].append(c);s['child_wrapper_exit']=c['exit_code'];s['passing_control']=e['passing_control']
    r=json.loads((wd/'child/results.json').read_bytes());log=(wd/'child'/e['name']/'2.log').read_text(encoding='utf-8');mutation=None
    for command in r['suites'][0]['commands']:assert digest(wd/'child'/e['name']/command['log'])==command['sha256']
    if e['fault'] in TRANSFORMS:
     _,mutation=prepare(source/'rtl/design.sv',wd/'expected-mutation',e['fault'],lock['revision'])
     assert digest(wd/'child'/e['name']/'disposable-rtl/design.sv')==mutation['compiled_sha256']
    s.update(qualify_fault(e,c,r,log,report,lock,child_nonce,mutation))
   else:
    extra=[];sim_extra=[];plus=['+RUN_ID='+nonce]
    if e['kind']=='sva':
     files=[src/'vga_bus.sv',src/'vga_assertions.sv',src/'vga_sva_control.sv'];top='vga_sva_control';plus+=['+SCENARIO='+e['scenario']]
     marker=rf'^# VGA_SVA_CONTROL_PASS name={e["scenario"]} detections={len(e["expected_sva"])}\s*$'
    else:
     rtl=source/'rtl/design.sv'
     if e.get('fault') in TRANSFORMS:rtl,s['mutation']=prepare(rtl,wd/'disposable-rtl',e['fault'],lock['revision'])
     files=[src/'vga_bus.sv',rtl,src/'vga_assertions.sv',src/'vga_uvm_pkg.sv',src/'vga_uvm_top.sv'];top='vga_uvm_top'
     extra=['-L',str(a.uvm_lib),'+incdir+'+str(a.uvm_include)];sim_extra=['-L',str(a.uvm_lib)];plus+=['+GROUP='+e['group']]
     if e.get('fault')=='driver_alias':plus+=['+DRIVER_ALIAS']
     marker=rf'^# VGA_UVM_PASS cases={len(e["cases"])} observations=\d+ comparisons=\d+ assertions=0 seed=0x28A6BEEF\s*$'
     if e.get('fault')=='missing_marker':marker=r'^# VGA_INTENTIONALLY_MISSING_REQUIRED_MARKER$'
    commands=[[tool(a.sim_bin,'vlib'),'work'],[tool(a.sim_bin,'vlog'),'-sv','-work','work',*extra,*files],[tool(a.sim_bin,'vsim'),'-c','-onfinish','exit','-voptargs=+acc','-sv_seed','682016495',*sim_extra,'work.'+top,*plus,'-do','onerror {quit -force -code 1}; run -all; quit -force -code 0']]
    for i,cmd in enumerate(commands):
     c,t=invoke(cmd,wd,wd/f'{i}.log',a.raster_timeout if i==2 and e['kind']!='sva' else a.timeout);s['commands'].append(c)
     reason=failure(c,t,marker if i==2 else None)
     if reason:s.update(status='FAIL',reason=reason);break
    else:
     assert re.findall(r'^# VGA_RUN_ID (\S+)\s*$',t,re.M)==[nonce]
     detections=re.findall(r'^# VGA_SVA_DETECTED (\w+) time=',t,re.M)
     assert sorted(detections)==sorted(e.get('expected_sva',[]))
     s.update(status='PASS',reason='EXECUTED',observed_sva=detections)
     if e['kind']!='sva':
      assert re.findall(r'^# VGA_UVM_PASS ',t,re.M)==['# VGA_UVM_PASS ']
      s.update(validate_functional(report,e,wd,t));s['uvm_runtime_versions']=sorted(set(re.findall(r'\[Questa UVM\] (QUESTA_UVM-[\d.]+)',t)));assert s['uvm_runtime_versions']==['QUESTA_UVM-1.2.3']
  except (OSError,ValueError,KeyError,IndexError,TypeError,AssertionError) as error:s.update(status='FAIL',reason='QUALIFICATION_OR_ACCOUNTING',detail=str(error))
  save();print(s['name'],s['status'],s.get('reason'),flush=True)
 if not a.select:
  passed={s['name'] for s in report['suites'] if s['status']=='PASS'}
  for s in report['suites']:
   if s['kind']=='fault' and s.get('passing_control') not in passed:s.update(status='FAIL',reason='PASSING_CONTROL_NOT_EXECUTED')
 report['aggregate_exit_code']=int(len(report['suites'])!=len(steps) or any(s['status']!='PASS' for s in report['suites']))
 if 'source_lock' in report and 'observed_revision' in report['source_lock']:
  report['source_lock']['clean_after_execution']=not bool(git(source,'status','--porcelain')) and all(digest(source/p)==h for p,h in lock['execution_sha256'].items())
  if not report['source_lock']['clean_after_execution']:report['aggregate_exit_code']=1
 report['environment_clean_after_execution']=git(repo,'rev-parse','HEAD')==report['source_revision'] and not git(repo,'status','--porcelain') and all(digest(repo/p)==h for p,h in report['input_sha256'].items())
 if not report['environment_clean_after_execution']:report['aggregate_exit_code']=1
 report['milestone_pass']=not a.select and not a.raw_fault and report['aggregate_exit_code']==0
 report['finished_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();save();return report['aggregate_exit_code']
if __name__=='__main__':raise SystemExit(main())
