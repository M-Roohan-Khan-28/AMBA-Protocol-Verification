#!/usr/bin/env python3
"""Executable synthetic records against the actual production VGA predicate."""
import argparse,copy,json
from pathlib import Path
from run_vga_uvm import qualify_fault
from advanced_sim import digest,git
from vga_write_receipts import reconcile
def main():
 ap=argparse.ArgumentParser();ap.add_argument('--output',required=True,type=Path);a=ap.parse_args()
 assert not a.output.exists();a.output.mkdir(parents=True);repo=Path(__file__).resolve().parents[1]
 nonce='qualified-fixture-nonce'
 entry=dict(name='fault-rgb',fault='rgb',group='smoke',expected_fatal='VGA_RESET',expected_sva=['RESET'])
 report=dict(source_revision='a'*40,input_sha256={'sentinel':'b'*64})
 lock=dict(revision='c'*40,execution_sha256={'rtl/design.sv':'d'*64})
 mutation=dict(kind='rgb',source_revision=lock['revision'],locked_sha256='d'*64,compiled_sha256='e'*64,checkout_modified=False)
 commands=[dict(command=['vlib.exe','work'],exit_code=0,timed_out=False),dict(command=['vlog.exe','-sv','-work','work','vga_uvm_top.sv'],exit_code=0,timed_out=False),dict(command=['vsim.exe','-c','work.vga_uvm_top','+RUN_ID='+nonce,'+GROUP=smoke','-do','onerror {quit -force -code 1}; run -all; quit -force -code 0'],exit_code=0,timed_out=False)]
 outer=dict(exit_code=1,timed_out=False)
 result=dict(aggregate_exit_code=1,milestone_pass=False,raw_fault=True,run_id=nonce,source_revision=report['source_revision'],expected_environment_revision=report['source_revision'],input_sha256=report['input_sha256'],source_dirty=False,environment_clean_after_execution=True,selection=[entry['name']],required_selected=[entry['name']],source_lock=dict(observed_revision=lock['revision'],clean_after_execution=True,execution_files_sha256=lock['execution_sha256']),suites=[dict(name=entry['name'],status='FAIL',reason='PROCESS_OR_SIMULATOR_ERROR',commands=commands,mutation=mutation)])
 log='# VGA_RUN_ID '+nonce+'\n# VGA_SVA_DETECTED RESET time=1\n# UVM_FATAL file.sv(1) @ 1: reporter [VGA_RESET] intentional\n'
 rows=[]
 def check(name,expect,mutate=None,output=log):
  e,o,r=copy.deepcopy(entry),copy.deepcopy(outer),copy.deepcopy(result)
  if mutate:mutate(e,o,r)
  try:qualify_fault(e,o,r,output,report,lock,nonce,mutation);accepted=True
  except (AssertionError,KeyError,IndexError,TypeError):accepted=False
  rows.append(dict(name=name,expected_accept=expect,accepted=accepted,pass_=accepted==expect))
 check('valid_intended_failure',True)
 for i in range(3):
  for code in (211,127,-11):check(f'tool_{i}_exit_{code}',False,lambda e,o,r,i=i,code=code:r['suites'][0]['commands'][i].update(exit_code=code))
  check(f'tool_{i}_timeout',False,lambda e,o,r,i=i:r['suites'][0]['commands'][i].update(timed_out=True))
  check(f'tool_{i}_incomplete_arguments',False,lambda e,o,r,i=i:r['suites'][0]['commands'][i].update(command=r['suites'][0]['commands'][i]['command'][:1]))
 check('outer_timeout',False,lambda e,o,r:o.update(timed_out=True))
 check('outer_success',False,lambda e,o,r:o.update(exit_code=0))
 check('missing_command',False,lambda e,o,r:r['suites'][0]['commands'].pop())
 check('stale_nonce_json',False,lambda e,o,r:r.update(run_id='old'))
 check('stale_nonce_log',False,output=log.replace(nonce,'old'))
 check('changed_source',False,lambda e,o,r:r.update(source_revision='f'*40))
 check('expected_source_mismatch',False,lambda e,o,r:r.update(expected_environment_revision='f'*40))
 check('changed_inputs',False,lambda e,o,r:r.update(input_sha256={}))
 check('dirty_source',False,lambda e,o,r:r.update(source_dirty=True))
 check('changed_dut',False,lambda e,o,r:r['source_lock'].update(observed_revision='f'*40))
 check('changed_dut_inputs',False,lambda e,o,r:r['source_lock'].update(execution_files_sha256={}))
 check('wrong_mutation',False,lambda e,o,r:r['suites'][0]['mutation'].update(compiled_sha256='f'*64))
 check('missing_diagnostic',False,output=log.split('# UVM_FATAL')[0])
 check('wrong_diagnostic',False,output=log.replace('[VGA_RESET]','[OTHER]'))
 check('extra_diagnostic',False,output=log+log.splitlines()[-1]+'\n')
 check('wrong_sva',False,output=log.replace('DETECTED RESET','DETECTED RGB'))
 check('extra_sva',False,output=log+'# VGA_SVA_DETECTED BLANK time=1\n')
 check('unrelated_fatal',False,output=log+'# ** Fatal: SIGSEGV\n')
 check('unrelated_error',False,output=log+'# ** Error: BAD\n')
 check('timeout_text',False,output=log+'VGA_PROGRESS_TIMEOUT\n')
 def marker(e,o,r):
  e.update(name='fault-missing_marker',fault='missing_marker',expected_fatal='',expected_sva=[])
  r.update(selection=[e['name']],required_selected=[e['name']]);r['suites'][0].update(name=e['name'],reason='MISSING_RESULT_MARKER')
 completed='# VGA_RUN_ID '+nonce+'\n# VGA_UVM_PASS cases=1 observations=9 comparisons=54 assertions=0 seed=0x28A6BEEF\n'
 check('valid_missing_marker',True,marker,completed)
 check('missing_marker_without_completion',False,marker,'# VGA_RUN_ID '+nonce+'\n')
 check('extra_completion',False,marker,completed+completed.splitlines()[-1]+'\n')
 intent=[(0,1,0,0,0),(7000,0,1,0,90),(32000,0,0,0,0)]
 accepted=[(15000,0,0,90,1),(25000,0,0,90,1)]
 def receipt(name,expect,i=intent,a=accepted):
  try:reconcile(i,a,40000);actual=True
  except (AssertionError,ValueError,IndexError,TypeError):actual=False
  rows.append(dict(name='receipt_'+name,expected_accept=expect,accepted=actual,pass_=actual==expect))
 receipt('valid_held_enable',True)
 receipt('missing_held_write',False,a=accepted[:1])
 receipt('extra_write',False,a=accepted+[(35000,0,0,90,1)])
 receipt('address_alias',False,a=[(15000,0,256,90,1),accepted[1]])
 receipt('wrong_data',False,a=[(15000,0,0,91,1),accepted[1]])
 receipt('wrong_reset',False,a=[(15000,1,0,90,1),accepted[1]])
 receipt('wrong_validity',False,a=[(15000,0,0,90,0),accepted[1]])
 receipt('out_of_order',False,a=list(reversed(accepted)))
 receipt('legal_coincident_reset',True,i=[*intent[:2],(15000,1,1,0,90),intent[-1]],a=[(15000,1,0,90,1),(25000,1,0,90,1)])
 receipt('ambiguous_clock_data',False,i=[*intent[:2],(15000,0,1,0,91),intent[-1]],a=[(15000,0,0,91,1),(25000,0,0,91,1)])
 code=int(not all(r['pass_'] for r in rows))
 out=dict(kind='SYNTHETIC_RECORD_FIXTURES_NOT_INDUCED_CRASHES',status='FAIL' if code else 'PASS',exit_code=code,checks=len(rows),cases=rows,tested_environment=git(repo,'rev-parse','HEAD'),production_sha256=digest(repo/'scripts/run_vga_uvm.py'),qualification_sha256=digest(Path(__file__)))
 (a.output/'results.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
 print(f'VGA_RUNNER_QUALIFICATION_{out["status"]} checks={len(rows)} failures={sum(not r["pass_"] for r in rows)}');return code
if __name__=='__main__':raise SystemExit(main())
