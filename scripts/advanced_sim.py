"""Shared bounded subprocess/log validation for the separate advanced milestone."""
import hashlib
import os
from pathlib import Path
import re
import signal
import subprocess

def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def run(command, cwd, timeout, log):
    command = [str(x) for x in command]
    try:
        p = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             start_new_session=os.name != 'nt',
                             creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if os.name == 'nt' else 0)
        timed_out = False
        try:
            data, _ = p.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            if os.name == 'nt':
                subprocess.run(['taskkill','/PID',str(p.pid),'/T','/F'], capture_output=True, timeout=15)
            else:
                os.killpg(p.pid, signal.SIGKILL)
            data, _ = p.communicate(timeout=15)
        code = p.returncode
    except OSError as error:
        data, code, timed_out = str(error).encode(), 127, False
    Path(log).write_bytes(data)
    text = data.decode('utf-8', errors='replace')
    record = dict(command=command, cwd=str(cwd), exit_code=code, timed_out=timed_out,
                  log=Path(log).name, sha256=hashlib.sha256(data).hexdigest())
    return record, text

def failure(record, text, marker=None):
    if record['timed_out']: return 'TIMEOUT'
    errors = bool(re.search(r'\*\*\s*(?:Error|Fatal)\b|UVM_(?:ERROR|FATAL)\s+.*@',text))
    errors |= any(int(x) for x in re.findall(r'(?:Errors|UVM_ERROR|UVM_FATAL)\s*:\s*(\d+)', text))
    if record['exit_code'] or errors:
        if re.search(r'checkout.*licen[cs]e|check out.*licen[cs]e|svverification', text,re.I):
            return 'LICENCE_BLOCKED'
        return 'PROCESS_OR_SIMULATOR_ERROR'
    if marker and not re.search(marker,text,re.M): return 'MISSING_RESULT_MARKER'
    return None

def git(repo,*args):
    return subprocess.check_output(['git','-C',str(repo),*args], text=True).strip()

def tool(folder,name):
    return Path(folder)/(name+('.exe' if os.name=='nt' else ''))
