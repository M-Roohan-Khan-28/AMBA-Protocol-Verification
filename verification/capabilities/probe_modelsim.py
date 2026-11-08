#!/usr/bin/env python3
"""Run separate ModelSim/Questa feature probes; never treats a skip as PASS.

Python 3.9+. No downloads, licence changes, or assumptions about precompiled UVM.
No simulator/probe is reported supported until compile AND simulation succeed.
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys

FEATURES = ("basic", "interfaces", "classes_random", "sva", "coverage", "uvm")


def simulator_errors(output):
    failures = []
    for line in output.splitlines():
        if re.search(r"\*\*\s*(?:Error|Fatal)\b|\bFATAL:\s|\bUVM_(?:ERROR|FATAL)\b[^\r\n]*@", line, re.I):
            failures.append(line)
        total = re.search(r"\bUVM_(?:ERROR|FATAL)\s*:\s*(\d+)", line)
        if total and int(total.group(1)):
            failures.append(line)
        simulator_total = re.search(r"\bErrors\s*:\s*(\d+)", line, re.I)
        if simulator_total and int(simulator_total.group(1)):
            failures.append(line)
    return failures


def classification(returncode, output, marker=None, timed_out=False):
    if timed_out:
        return "FAIL", "TIMEOUT"
    failed = returncode != 0 or bool(simulator_errors(output))
    if failed:
        if re.search(r"licen[cs]e|svverification", output, re.I):
            return "BLOCKED", "SIMULATOR_LICENCE_OR_FEATURE"
        return "FAIL", "NONZERO_EXIT_OR_SIMULATOR_ERROR"
    if marker and not re.search(r"(?m)^\s*(?:#\s*)?" + re.escape(marker) + r"\s*$", output):
        return "FAIL", "MISSING_RESULT_MARKER"
    return "PASS", "EXECUTED"


def run_command(command, cwd, timeout, logfile):
    creationflags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
    proc = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            text=True, errors="replace", shell=False,
                            start_new_session=os.name != "nt", creationflags=creationflags)
    timed_out = False
    try:
        output, _ = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        timed_out = True
        if os.name == "nt":
            subprocess.run(["taskkill", "/PID", str(proc.pid), "/T", "/F"],
                           capture_output=True, timeout=15, check=False)
        else:
            os.killpg(proc.pid, signal.SIGKILL)
        output, _ = proc.communicate(timeout=15)
    Path(logfile).write_text(output, encoding="utf-8")
    return {"command": command, "cwd": str(cwd), "exit_code": proc.returncode, "timed_out": timed_out,
            "log": str(Path(logfile).name), "output": output}


def locate(name, folder):
    if folder:
        for suffix in (".exe", "") if os.name == "nt" else ("", ".exe"):
            path = folder / (name + suffix)
            if path.is_file():
                return str(path.resolve())
        return None
    return shutil.which(name)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim-bin", type=Path, help="directory containing vlib, vlog, and vsim")
    parser.add_argument("--output", required=True, type=Path, help="new, unused output directory")
    parser.add_argument("--timeout", type=int, default=60, help="wall seconds per process")
    parser.add_argument("--uvm-lib", help="installed, mapped precompiled UVM library; never guessed")
    parser.add_argument("--uvm-include", type=Path, help="directory containing matching uvm_macros.svh")
    parser.add_argument("--features", nargs="+", choices=FEATURES, default=list(FEATURES))
    parser.add_argument("--modelsimini", type=Path, help="existing ini containing the UVM/library mappings")
    args = parser.parse_args(argv)
    if args.output.exists():
        parser.error("Output already exists. Preserve it and choose a fresh directory.")
    if args.timeout < 1:
        parser.error("Timeout must be positive")
    args.output.mkdir(parents=True)
    args.output = args.output.resolve()
    executables = {name: locate(name, args.sim_bin) for name in ("vlib", "vlog", "vsim")}
    records = []
    report = {"schema_version": 1, "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "purpose": "TOOL_FEATURE_PROBE_ONLY_NOT_PROJECT_REGRESSION", "tools": executables,
              "seed": "0x28a6beef", "features": records}
    repo=Path(__file__).resolve().parents[2]
    report["source_revision"]=subprocess.check_output(["git","-C",str(repo),"rev-parse","HEAD"],text=True).strip()
    report["source_dirty"]=bool(subprocess.check_output(["git","-C",str(repo),"status","--porcelain"],text=True).strip())
    report["runner_sha256"]=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
    missing = [name for name, path in executables.items() if not path]
    sources = Path(__file__).resolve().parent / "probes"
    version_ok = False
    if not missing:
        try:
            version = run_command([executables["vsim"], "-version"], args.output, min(args.timeout, 30), args.output / "version.log")
            report["version_probe"] = {k:v for k,v in version.items() if k != "output"}
            report["version_text"] = version["output"]
            version_status, version_reason = classification(version["exit_code"], version["output"], timed_out=version["timed_out"])
            version_ok = version_status == "PASS" and bool(version["output"].strip())
            report["version_status"] = "PASS" if version_ok else "FAIL"
            if not version_ok:
                report["version_error"] = version_reason if version["output"].strip() else "EMPTY_VERSION_OUTPUT"
        except (OSError, subprocess.SubprocessError) as error:
            report["version_error"] = str(error)
    for feature in args.features:
        source = sources / (feature + ".sv")
        record = {"feature": feature, "source": source.name, "commands": []}
        records.append(record)
        if not source.is_file():
            record.update(status="BLOCKED", reason="MISSING_PROBE_SOURCE")
            continue
        record["source_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
        if missing:
            record.update(status="BLOCKED", reason="MISSING_TOOLS", missing=missing)
            continue
        if feature == "uvm" and (not args.uvm_lib or not args.uvm_include or not (args.uvm_include / "uvm_macros.svh").is_file()):
            record.update(status="BLOCKED", reason="UVM_LIBRARY_AND_MATCHING_HEADERS_NOT_CONFIGURED")
            continue
        work = args.output / feature
        work.mkdir()
        ini_args = ["-modelsimini", str(args.modelsimini.resolve())] if args.modelsimini else []
        compile_args, sim_args = [], []
        if feature == "uvm":
            compile_args = ["-L", args.uvm_lib, "+incdir+" + str(args.uvm_include.resolve())]
            sim_args = ["-L", args.uvm_lib]
        if feature == "coverage":
            sim_args += ["-coverage"]
        sim_do = "onerror {quit -force -code 1}; run -all; "
        if feature == "coverage":
            sim_do += "coverage save coverage.ucdb; "
        sim_do += "quit -force -code 0"
        commands = [
            [executables["vlib"], "work"],
            [executables["vlog"], *ini_args, "-sv", "-work", "work", *compile_args, str(source)],
            [executables["vsim"], *ini_args, "-c", "-onfinish", "stop", *sim_args, "work.probe_" + feature,
             "-do", sim_do],
        ]
        for index, command in enumerate(commands):
            try:
                result = run_command(command, work, args.timeout, work / (str(index) + ".log"))
                status, reason = classification(result["exit_code"], result["output"],
                                                "FEATURE_PASS_" + feature if index == 2 else None,
                                                result["timed_out"])
                record["commands"].append({k:v for k,v in result.items() if k != "output"})
            except (OSError, subprocess.SubprocessError) as error:
                status, reason = "BLOCKED", "EXECUTION_ERROR: " + str(error)
            record.update(status=status, reason=reason)
            if status != "PASS":
                break
        if feature == "coverage":
            record["coverage_export"] = "NOT RUN: simulation did not qualify"
            if record.get("status") == "PASS":
                vcover = locate("vcover", args.sim_bin)
                ucdb = work / "coverage.ucdb"
                if not vcover or not ucdb.is_file():
                    record.update(status="BLOCKED",reason="MISSING_VCOVER_OR_UCDB")
                else:
                    result=run_command([vcover,"report","-details","-cvg","-output","coverage.txt","coverage.ucdb"],work,args.timeout,work/"3.log")
                    record["commands"].append({k:v for k,v in result.items() if k!="output"})
                    status,reason=classification(result["exit_code"],result["output"],timed_out=result["timed_out"])
                    exported=work/"coverage.txt"
                    report_text=exported.read_text(errors="replace") if exported.is_file() else ""
                    if status=="PASS" and not re.search(r"Covergroup|Coverpoint",report_text,re.I):
                        status,reason="FAIL","MISSING_FUNCTIONAL_COVERAGE_REPORT"
                    record.update(status=status,reason=reason)
                    if status=="PASS":
                        record["coverage_export"]="EXPORTED"
                        record["coverage_report_sha256"]=hashlib.sha256(exported.read_bytes()).hexdigest()
    report["aggregate_status"] = "PASS" if version_ok and all(r["status"] == "PASS" for r in records) else "INCOMPLETE"
    destination = args.output / "feature-results.json"
    destination.write_text(json.dumps(report, indent=2)+"\n", encoding="utf-8")
    print(json.dumps({"result": report["aggregate_status"], "report": str(destination),
                      "features": [{k:v for k,v in r.items() if k in ("feature", "status", "reason")} for r in records]}, indent=2))
    return 0 if report["aggregate_status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
