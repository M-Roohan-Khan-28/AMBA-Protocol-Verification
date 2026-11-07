#!/usr/bin/env python3
"""Directed monitor qualification; does not replace the existing regression.

Every negative case must log exactly the expected fatal diagnostic. ModelSim
Starter can return process status zero even for $fatal, so the transcript is
authoritative and the actual simulator status is recorded. A timeout, compile
failure, unrelated fatal, or missing marker is a failed qualification.
--baseline-probe requires the reviewed old checker bytes
and demonstrates the old checker blind spots; it is not a DUT PASS.
"""
import argparse, datetime, hashlib, json, os, pathlib, re, shutil, subprocess, sys

REPO_NAME = "AXI4-Lite-Memory-Interface"
BASELINE_SHA = "a7b9540f225282e1ffbddf84531e6e5a34e73a86"
CHECKER_REL = "tb/legacy/axi_protocol_checker.sv"
CHECKER_BLOB = "684253abe311bc077ad4077b781b5dec9c866b09"
INTERFACE_REL = "rtl/axi/axi_lite_if.sv"
CASE_IDS = {
    0: "legal_aw_first_w_first_together_and_read_backpressure",
    1: "b_without_aw_or_w_held",
    2: "b_after_only_aw_held",
    3: "b_after_only_w_held",
    4: "r_without_ar_held",
    5: "same_edge_aw_w_b",
    6: "same_edge_ar_r",
    7: "older_aw_same_edge_w_b",
    8: "older_w_same_edge_aw_b",
}

def blob_hash(data):
    return hashlib.sha1(b"blob " + str(len(data)).encode() + b"\0" + data).hexdigest()

def executable(name):
    directory = os.environ.get("MODELSIM_BIN")
    for candidate in ([str(pathlib.Path(directory) / (name + ".exe")),
                       str(pathlib.Path(directory) / name)] if directory else []) + [name, name + ".exe"]:
        found = shutil.which(candidate)
        if found:
            return found
    raise RuntimeError("Missing required executable: " + name)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", type=pathlib.Path, default=pathlib.Path(__file__).resolve().parents[1])
    parser.add_argument("--output-dir", type=pathlib.Path, required=True)
    parser.add_argument("--checker-source", type=pathlib.Path)
    parser.add_argument("--baseline-probe", action="store_true")
    parser.add_argument("--timeout-seconds", type=int, default=60)
    args = parser.parse_args()
    root = args.repo_root.resolve()
    out = args.output_dir.resolve()
    if out.exists():
        raise RuntimeError("Output directory already exists; choose a new evidence directory")
    out.mkdir(parents=True)
    report = {
        "schema_version": 1,
        "kind": "monitor_negative_control_qualification",
        "repository": REPO_NAME,
        "reviewed_baseline": BASELINE_SHA,
        "started_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "baseline_probe": args.baseline_probe,
        "seed": None,
        "seed_note": "Directed cases; no pseudorandom stimulus",
        "commands": [],
        "cases": [],
        "overall": "FAIL",
    }
    def run(command, label, timeout=None):
        report["commands"].append({"label": label, "argv": command, "cwd": str(out)})
        try:
            result = subprocess.run(command, cwd=out, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    timeout=timeout or args.timeout_seconds, check=False)
        except subprocess.TimeoutExpired as exc:
            (out / (label + ".log")).write_bytes(exc.stdout or b"")
            raise RuntimeError("Timed out: " + label) from exc
        data = result.stdout
        (out / (label + ".log")).write_bytes(data)
        return result.returncode, data.decode("utf-8", errors="replace")
    try:
        if args.timeout_seconds < 1:
            raise RuntimeError("Timeout must be positive")
        head = subprocess.run(["git", "-C", str(root), "rev-parse", "HEAD"], check=True,
                              capture_output=True, text=True).stdout.strip()
        dirty = subprocess.run(["git", "-C", str(root), "status", "--porcelain"], check=True,
                               capture_output=True, text=True).stdout
        report["observed_head"] = head
        report["worktree_status"] = dirty
        checker = (args.checker_source or root / CHECKER_REL).resolve()
        interface = root / INTERFACE_REL
        bench = root / "tb/checker_response_order_test.sv"
        for file in (checker, interface, bench):
            data = file.read_bytes()
            report.setdefault("input_files", []).append({
                "path": str(file), "sha256": hashlib.sha256(data).hexdigest(),
                "raw_git_blob": blob_hash(data), "lf_normalized_git_blob": blob_hash(data.replace(b"\r\n", b"\n"))
            })
        checker_bytes = checker.read_bytes()
        if args.baseline_probe:
            # Accept Windows checkout line-ending conversion but no source edits.
            variants = [checker_bytes, checker_bytes.replace(b"\r\n", b"\n"),
                        checker_bytes.replace(b"\r\n", b"\n").replace(b"\n", b"\r\n")]
            if CHECKER_BLOB not in [blob_hash(item) for item in variants]:
                raise RuntimeError("Legacy checker bytes do not match the reviewed Git blob")
        elif b"AXI_CHECKER_B_DEPENDENCY" not in checker_bytes or b"AXI_CHECKER_R_DEPENDENCY" not in checker_bytes:
            raise RuntimeError("Corrected checker dependency diagnostics are absent")
        vlib, vlog, vsim = (executable(tool) for tool in ("vlib", "vlog", "vsim"))
        for tool in (vlog, vsim):
            code, _ = run([tool, "-version"], pathlib.Path(tool).stem + "-version")
            if code:
                raise RuntimeError("Simulator version query failed: " + tool)
        code, _ = run([vlib, "work"], "vlib")
        if code:
            raise RuntimeError("vlib failed")
        code, log = run([vlog, "-sv", str(interface), str(checker), str(bench)], "compile")
        if code or re.search(r"\*\*\s+(?:Error|Fatal):", log):
            raise RuntimeError("Compilation failed")
        for number, name in CASE_IDS.items():
            command = [vsim, "-c", "-onfinish", "exit", "checker_response_order_test",
                       "+CASE=" + str(number), "-do",
                       "onerror {quit -code 1}; onbreak {quit -code 1}; run -all; quit -code 0"]
            code, log = run(command, "case-" + str(number))
            generic_error = bool(re.search(r"\*\*\s+Error:", log))
            forbidden = bool(re.search(r"CHECKER_ORDER_(?:TIMEOUT|INVALID_CASE|POSITIVE_COUNTS)", log))
            monitor_token = "AXI_CHECKER_R_DEPENDENCY" if number in (4, 6) else "AXI_CHECKER_B_DEPENDENCY"
            fatals = [line for line in log.splitlines() if re.search(r"\*\*\s+Fatal:", line)]
            if number == 0:
                ok = code == 0 and "CHECKER_ORDER_POSITIVE_PASS writes=999 reads=1" in log
                ok = ok and not re.search(r"\*\*\s+(?:Error|Fatal):", log)
                status = "LEGAL_TRAFFIC_ACCEPTED" if ok else "FAIL"
            elif args.baseline_probe:
                expected = "CHECKER_ORDER_UNDETECTED case=" + str(number)
                ok = len(fatals) == 1 and expected in fatals[0] and monitor_token not in log
                ok = ok and not generic_error and not forbidden
                status = "LEGACY_BLIND_SPOT_EXPOSED" if ok else "FAIL"
            else:
                ok = len(fatals) == 1 and monitor_token in fatals[0] and "CHECKER_ORDER_UNDETECTED" not in log
                ok = ok and not generic_error and not forbidden
                # A second fatal or unexpected simulator diagnostic cannot count as detection.
                status = "EXPECTED_VIOLATION_DETECTED" if ok else "FAIL"
            report["cases"].append({"case": number, "name": name, "exit_code": code,
                                    "result": status, "log": "case-" + str(number) + ".log"})
            if not ok:
                raise RuntimeError("Unexpected result in case " + str(number))
        report["overall"] = "BASELINE_BLIND_SPOTS_DEMONSTRATED" if args.baseline_probe else "QUALIFICATION_PASS"
    except Exception as exc:
        report["error"] = str(exc)
    finally:
        report["finished_utc"] = datetime.datetime.now(datetime.timezone.utc).isoformat()
        (out / "RESULTS.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        summary = [report["overall"], "Repository: " + REPO_NAME, "Reviewed baseline: " + BASELINE_SHA,
                   "Observed HEAD: " + report.get("observed_head", "UNAVAILABLE"),
                   "No random seed: directed monitor qualification."]
        summary += ["case {case}: {name}: {result} (exit {exit_code})".format(**row) for row in report["cases"]]
        if "error" in report:
            summary.append("ERROR: " + report["error"])
        (out / "SUMMARY.txt").write_text("\n".join(summary) + "\n", encoding="utf-8")
        print("\n".join(summary))
    return 0 if report["overall"] in ("QUALIFICATION_PASS", "BASELINE_BLIND_SPOTS_DEMONSTRATED") else 1

if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:
        print("FAIL: " + str(error), file=sys.stderr)
        sys.exit(1)
