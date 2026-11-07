#!/usr/bin/env python3
"""Qualify isolated AXI4 response negatives with disposable monitor faults.

The original monitor is never edited. ModelSim Starter may return zero for
``$fatal``; the exact fatal transcript and preceding case markers are checked.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import time


def tool(name):
    prefix = os.environ.get("MODELSIM_BIN", "")
    found = shutil.which(str(Path(prefix) / (name + ".exe"))) if prefix else None
    found = found or shutil.which(name)
    if not found:
        raise RuntimeError("Required simulator tool missing: " + name)
    return found


def run(command, cwd, logfile, timeout=90):
    try:
        completed = subprocess.run(command, cwd=cwd, capture_output=True,
                                   timeout=timeout, check=False)
    except subprocess.TimeoutExpired as exc:
        logfile.write_bytes((exc.stdout or b"") + (exc.stderr or b""))
        raise RuntimeError("Timeout: " + " ".join(command)) from exc
    data = completed.stdout + completed.stderr
    logfile.write_bytes(data)
    return completed.returncode, data.decode("utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = args.output_dir.resolve()
    if output.exists():
        raise RuntimeError("Output directory exists: " + str(output))
    output.mkdir(parents=True)
    monitor = root / "checkers/axi4_burst_monitor.sv"
    bench = root / "tb/axi4_response_negative.sv"
    original = monitor.read_text(encoding="utf-8")
    b_rule = 'if(bvalid && (!pre_write_complete || bid!=0))'
    r_rule = 'if(rvalid && !pre_read_active)'
    if original.count(b_rule) != 1 or original.count(r_rule) != 1:
        raise RuntimeError("Expected monitor predicates changed")
    cases = [
        ("original", original, 4, None),
        ("mask_same_edge_b", original.replace(b_rule,
            'if(bvalid && (!pre_write_complete || bid!=0) && !(awvalid&&awready&&wvalid&&wready))'),
            2, "same-edge AXI4 B dependency: expected 1 violation, got 0"),
        ("mask_same_edge_r", original.replace(r_rule,
            'if(rvalid && !pre_read_active && !(arvalid&&arready))'),
            3, "same-edge AXI4 R dependency: expected 1 violation, got 0"),
    ]
    report = {"repository": "AMBA-Protocol-Verification", "source_head":
              subprocess.check_output(["git", "-C", str(root), "rev-parse", "HEAD"],
                                      text=True).strip(),
              "monitor_sha256": hashlib.sha256(monitor.read_bytes()).hexdigest(),
              "bench_sha256": hashlib.sha256(bench.read_bytes()).hexdigest(),
              "stimulus": "directed; no random seed", "cases": [], "overall": "FAIL"}
    try:
        vlib, vlog, vsim = (tool(name) for name in ("vlib", "vlog", "vsim"))
        report["simulator_version"] = run([vsim, "-version"], output,
                                          output / "version.log")[1].strip()
        for name, source, expected_prior, expected_fatal in cases:
            directory = output / name
            directory.mkdir()
            mutated = directory / "axi4_burst_monitor.sv"
            mutated.write_text(source, encoding="utf-8")
            start = time.monotonic()
            lib_code, _ = run([vlib, "work"], directory, directory / "library.log")
            compile_code, compile_log = run([vlog, "-sv", str(mutated), str(bench)],
                                             directory, directory / "compile.log")
            if lib_code or compile_code or not re.search(r"Errors: 0, Warnings: 0", compile_log):
                raise RuntimeError(name + " compile failed")
            sim_code, log = run([vsim, "-c", "-onfinish", "exit", "axi4_response_negative",
                                 "-do", "run -all; quit -code 0"], directory,
                                directory / "simulation.log")
            markers = re.findall(r"AXI4_NEGATIVE_CASE_PASS (\S+)", log)
            fatals = re.findall(r"(?m)^# \*\* Fatal: (.+)$", log)
            passed = len(markers) == expected_prior
            if expected_fatal is None:
                passed &= sim_code == 0 and not fatals and \
                    len(re.findall(r"AMBA_AXI4_RESPONSE_NEGATIVE_PASS scenarios=4 violations=1", log)) == 1 \
                    and "# Errors: 0, Warnings: 0" in log
            else:
                passed &= len(fatals) == 1 and expected_fatal in fatals[0] \
                    and "AMBA_AXI4_RESPONSE_NEGATIVE_PASS" not in log \
                    and "# Errors: 1" in log
            record = {"name": name, "status": "PASS" if passed else "FAIL",
                      "expected_prior_markers": expected_prior, "observed_prior_markers": markers,
                      "expected_fatal": expected_fatal, "observed_fatals": fatals,
                      "simulator_exit_code": sim_code, "timeout_seconds": 90,
                      "elapsed_seconds": round(time.monotonic() - start, 3)}
            report["cases"].append(record)
            print(name + ": " + record["status"])
            if not passed:
                raise RuntimeError(name + " did not produce the expected result")
        report["overall"] = "PASS"
    except Exception as exc:
        report["error"] = str(exc)
        print("FAIL: " + str(exc))
    finally:
        (output / "results.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return 0 if report["overall"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
