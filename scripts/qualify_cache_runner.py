#!/usr/bin/env python3
"""Synthetic record fixtures qualify the production decision, not crash hardware."""
import argparse,copy,json
from pathlib import Path
from run_cache_uvm import qualify_fault
from advanced_sim import digest,git
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
 assert not a.output.exists();a.output.mkdir(parents=True)
 repo=Path(__file__).resolve().parent.parent
 entry=dict(name='fault-corrupted_data',fault='corrupted_data',mutation='corrupted_data',expected_fatal='CACHE_DATA')
 report=dict(source_revision='a'*40,input_sha256={'sentinel':'b'*64});lock=dict(revision='c'*40,sha256={'rtl/design.sv':'d'*64})
 outer=dict(exit_code=1,timed_out=False)
 result=dict(aggregate_exit_code=1,source_revision=report['source_revision'],input_sha256=report['input_sha256'],raw_fault=True,environment_clean_after_execution=True,source_lock=dict(observed_revision=lock['revision'],clean_after_execution=True),suites=[dict(name=entry['name'],status='FAIL',reason='PROCESS_OR_SIMULATOR_ERROR',commands=[dict(exit_code=0,timed_out=False) for _ in range(3)],mutation=dict(kind=entry['mutation'],source_revision=lock['revision'],locked_sha256=lock['sha256']['rtl/design.sv'],compiled_sha256='e'*64,checkout_modified=False))])
 log='# UVM_FATAL file.sv(1) @ 1: reporter [CACHE_DATA] intentional\n'
 cases=[]
 def check(name,expect,mutate=None,output=log):
  e,o,r=copy.deepcopy(entry),copy.deepcopy(outer),copy.deepcopy(result)
  if mutate:mutate(e,o,r)
  try:qualify_fault(e,o,r,output,report,lock);actual=True
  except (AssertionError,KeyError,IndexError,TypeError):actual=False
  cases.append(dict(name=name,expected_accept=expect,accepted=actual,pass_=actual==expect))
 check('valid_expected_data_failure',True)
 for i in range(3):
  for code in (211,127,-11):check(f'tool_{i}_exit_{code}',False,lambda e,o,r,i=i,code=code:r['suites'][0]['commands'][i].update(exit_code=code))
  check(f'tool_{i}_timeout',False,lambda e,o,r,i=i:r['suites'][0]['commands'][i].update(timed_out=True))
 check('outer_timeout',False,lambda e,o,r:o.update(timed_out=True))
 check('outer_success',False,lambda e,o,r:o.update(exit_code=0))
 check('changed_environment',False,lambda e,o,r:r.update(source_revision='f'*40))
 check('changed_inputs',False,lambda e,o,r:r.update(input_sha256={}))
 check('wrong_dut_lock',False,lambda e,o,r:r['source_lock'].update(observed_revision='f'*40))
 check('dirty_dut',False,lambda e,o,r:r['source_lock'].update(clean_after_execution=False))
 check('missing_tool_command',False,lambda e,o,r:r['suites'][0]['commands'].pop())
 check('wrong_diagnostic',False,output=log.replace('CACHE_DATA','OTHER'))
 check('extra_fatal',False,output=log+log)
 check('unrelated_crash',False,output=log+'# ** Fatal: SIGSEGV\n')
 check('timeout_marker',False,output=log+'CACHE_PROGRESS_TIMEOUT\n')
 check('missing_diagnostic',False,output='')
 def missing(e,o,r):
  e.update(name='fault-missing_marker',fault='missing_marker',mutation=None,expected_fatal='');r['suites'][0].update(name=e['name'],reason='MISSING_RESULT_MARKER')
 check('valid_missing_marker',True,missing,'# CACHE_UVM_PASS cases=1 assertions=0 seed=0x28A6BEEF\n')
 check('missing_marker_without_completion',False,missing,'')
 code=int(not all(c['pass_'] for c in cases))
 out=dict(kind='SYNTHETIC_RECORD_FIXTURES_NOT_INDUCED_CRASHES',status='FAIL' if code else 'PASS',exit_code=code,checks=len(cases),cases=cases,tested_environment=git(repo,'rev-parse','HEAD'),production_sha256=digest(repo/'scripts/run_cache_uvm.py'),qualification_sha256=digest(Path(__file__)))
 (a.output/'results.json').write_text(json.dumps(out,indent=2)+'\n')
 print(f'CACHE_RUNNER_QUALIFICATION_{out["status"]} checks={len(cases)} failures={sum(not c["pass_"] for c in cases)}');return code
if __name__=='__main__':raise SystemExit(main())
