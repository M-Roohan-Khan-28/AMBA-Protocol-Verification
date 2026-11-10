#!/usr/bin/env python3
"""Qualify the production AHB fault decision using immutable published fixtures.

No simulator is launched. Modified process records are synthetic fixtures, not
evidence of actual simulator crashes. The legacy comparison executes the exact
guard AST from the locked historical runner, without copying its decision rules.
"""
import argparse
import ast
import copy
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

from run_ahb_uvm import qualify_fault


def digest(data):
    return hashlib.sha256(data).hexdigest()


def legacy_qualifier(source):
    tree = ast.parse(source)
    candidates = []
    for node in ast.walk(tree):
        if isinstance(node, ast.Try) and any(
            isinstance(n, ast.Constant) and n.value == 'EXPECTED_CHILD_FAILURE'
            for statement in node.body for n in ast.walk(statement)
        ):
            candidates.append(node)
    assert len(candidates) == 1
    node = candidates[0]
    # The first statements only load result/log files; callers supply those exact
    # records. Retain cs assignment and every subsequent production decision.
    assert [n.targets[0].id for n in node.body[:3]] == ['result', 'log', 'cs']
    shell = ast.parse('def legacy(entry,c,result,log,report,lock):\n s={}\n return s\n')
    shell.body[0].body[1:1] = copy.deepcopy(node.body[2:])
    ast.fix_missing_locations(shell)
    namespace = {'re': re}
    exec(compile(shell, '<locked-historical-AHB-qualifier>', 'exec'), namespace)
    return namespace['legacy'], [node.body[2].lineno, node.body[-1].end_lineno]


def decide(qualifier, args):
    try:
        result = qualifier(**args)
        return result.get('status') == 'PASS', 'qualified'
    except (AssertionError, KeyError, IndexError, TypeError) as error:
        return False, type(error).__name__ + ': ' + str(error)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        parser.error('Require a fresh output directory')
    out = args.output.resolve()
    out.mkdir(parents=True)
    repo = Path(__file__).resolve().parent.parent
    manifest_path = repo / 'verification/ahb_uvm/runner_fixtures.json'
    manifest = json.loads(manifest_path.read_bytes())
    for path, expected in manifest['files'].items():
        assert digest((repo/path).read_bytes()) == expected, path
    ref = manifest['old_runner']
    historical = subprocess.check_output(['git', '-C', str(repo), 'show', ref['revision']+':'+ref['path']])
    assert digest(historical) == ref['sha256']
    old, lines = legacy_qualifier(historical)
    current = qualify_fault
    parent = json.loads((repo/manifest['parent_result']).read_bytes())
    report = dict(
        description=__doc__, tested_environment=subprocess.check_output(
            ['git', '-C', str(repo), 'rev-parse', 'HEAD'], text=True).strip(),
        production_qualifier_sha256=digest((repo/'scripts/run_ahb_uvm.py').read_bytes()),
        qualification_script_sha256=digest(Path(__file__).read_bytes()),
        fixture_manifest_sha256=digest(manifest_path.read_bytes()),
        historical_runner=ref, historical_executed_guard_lines=lines,
        fixture_input_sha256=manifest['files'], fixture_source_revision=parent['source_revision'],
        fixture_dut_revision=parent['source_lock']['revision'],
        command=[sys.executable, *sys.argv], python_version=sys.version,
        simulation_execution='NOT RUN - record fixtures only', cases=[])
    variants = ('original', 'sim_exit_211', 'sim_exit_127', 'sim_exit_-11',
                'sim_timeout', 'incomplete_tools', 'compile_exit_127',
                'library_exit_127', 'compile_timeout', 'missing_sim_exit',
                'wrong_source_revision', 'unexpected_diagnostic')
    for fixture in manifest['cases']:
        name = fixture['name']
        original = json.loads((repo/fixture['result']).read_bytes())
        original_log = (repo/fixture['log']).read_text(encoding='utf-8')
        parent_step = next(s for s in parent['suites'] if s['name'] == name)
        assert original['source_revision'] == parent['source_revision']
        assert original['input_sha256'] == parent['input_sha256']
        assert original['suites'][0]['commands'][2]['exit_code'] == 0
        for variant in variants:
            child = copy.deepcopy(original)
            log = original_log
            commands = child['suites'][0]['commands']
            change = None
            if variant.startswith('sim_exit_'):
                code = int(variant.removeprefix('sim_exit_'))
                commands[2]['exit_code'] = code
                change = dict(path='/suites/0/commands/2/exit_code', before=0, after=code)
            elif variant == 'sim_timeout':
                commands[2]['timed_out'] = True
                change = dict(path='/suites/0/commands/2/timed_out', before=False, after=True)
            elif variant == 'incomplete_tools':
                removed = commands.pop()
                change = dict(path='/suites/0/commands/2', before=removed, after='REMOVED')
            elif variant in ('compile_exit_127', 'library_exit_127'):
                index = 1 if variant.startswith('compile') else 0
                commands[index]['exit_code'] = 127
                change = dict(path=f'/suites/0/commands/{index}/exit_code', before=0, after=127)
            elif variant == 'compile_timeout':
                commands[1]['timed_out'] = True
                change = dict(path='/suites/0/commands/1/timed_out', before=False, after=True)
            elif variant == 'missing_sim_exit':
                del commands[2]['exit_code']
                change = dict(path='/suites/0/commands/2/exit_code', before=0, after='REMOVED')
            elif variant == 'wrong_source_revision':
                child['source_revision'] = '0'*40
                change = dict(path='/source_revision', before=original['source_revision'], after='0'*40)
            elif variant == 'unexpected_diagnostic':
                log += '\n** Error: injected unrelated fixture diagnostic\n'
                change = dict(path='log_append', after='** Error: injected unrelated fixture diagnostic')
            kwargs = dict(entry=fixture['entry'], c=parent_step['commands'][0],
                          result=child, log=log, report=parent, lock=parent['source_lock'])
            old_accept, old_reason = decide(old, kwargs)
            new_accept, new_reason = decide(current, kwargs)
            expected = variant == 'original'
            known_old_gap = name in ('fault-short_error', 'fault-missing_error') and (
                variant.startswith('sim_exit_') or variant == 'missing_sim_exit')
            expected_old = expected or known_old_gap
            row = dict(fixture=name, variant=variant, mutation=change,
                       old_accept=old_accept, corrected_accept=new_accept,
                       expected_old_accept=expected_old, expected_corrected_accept=expected,
                       old_reason=old_reason, corrected_reason=new_reason,
                       child_wrapper_exit=parent_step['commands'][0]['exit_code'],
                       fixture_child_sha256=digest(json.dumps(child,sort_keys=True).encode()),
                       original_log_sha256=manifest['files'][fixture['log']],
                       pass_result=old_accept==expected_old and new_accept==expected)
            row['pass'] = row.pop('pass_result')
            report['cases'].append(row)
            folder = out/name
            folder.mkdir(exist_ok=True)
            (folder/(variant+'.json')).write_bytes((json.dumps(child,indent=2)+'\n').encode())
            print(f"FIXTURE {name} {variant}: old={'ACCEPT' if old_accept else 'REJECT'} corrected={'ACCEPT' if new_accept else 'REJECT'} {'PASS' if row['pass'] else 'FAIL'}", flush=True)
    report['checks'] = len(report['cases'])
    report['failures'] = sum(not x['pass'] for x in report['cases'])
    report['exit_code'] = int(report['failures'] != 0)
    report['status'] = 'FAIL' if report['exit_code'] else 'PASS'
    (out/'results.json').write_bytes((json.dumps(report,indent=2)+'\n').encode())
    if not report['exit_code']:
        print(f"AHB_RUNNER_QUALIFICATION_PASS checks={report['checks']} failures=0")
    return report['exit_code']


if __name__ == '__main__':
    raise SystemExit(main())
