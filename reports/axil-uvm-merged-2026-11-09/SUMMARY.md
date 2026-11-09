# Merged-source deterministic AXI4-Lite UVM/SVA validation — 9 November 2026

**23/23 required substeps PASS; actual parent wrapper exit 0; project aggregate
exit 0.** This new report records a fresh detached GitHub clone of merged AMBA
source `cdbb7b1d2e1ae73e621f9de884119c44b19efd99`. Sessions ran serially using the already qualified Questa/UVM
configuration. The runner and locked DUT trees were clean. This is a separate
AXI4-Lite milestone; no new eleven-project aggregate or APB rerun is claimed.

## Reviewed merges and unchanged execution inputs

Authenticated owner: `M-Roohan-Khan-28`, immutable ID `270144410`. Both heads
matched the user-reviewed revisions. Neither PR had new reviews/comments,
unresolved threads, status checks or required checks. Each was merged normally
with its full head-SHA guard and verified destination push permission. Empty
check lists are not claimed as CI passes. [Merge receipts](MERGES.json):

| PR | Reviewed full head | Actual merge commit |
| --- | --- | --- |
| [AMBA-Protocol-Verification #10](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/pull/10) | `4278d78cdc41edc64f33507ee9e1b4172ff83768` | `cdbb7b1d2e1ae73e621f9de884119c44b19efd99` |
| [AXI4-Lite-Memory-Interface #3](https://github.com/M-Roohan-Khan-28/AXI4-Lite-Memory-Interface/pull/3) | `13fc1e167c7ede5898fc91a32b64862ab2ae7032` | `97f10ce845c83932c4d88743f1929ecf786cf54e` |

Both merged trees equal their reviewed head trees. All 12
execution inputs match the reviewed AMBA head and corrected implementation
`1263410134a27dda2c93741c3aa526001bf4469a` byte for byte. The DUT lock remains
**`faf43379b24a524999eb2c8ad7e100cde35054c3`**. The fresh DUT clone matched that
SHA and all five RTL hashes; the documentation merge changed no RTL blobs.
[Input and preservation checks](input-verification.json), [actual result/input
hashes](run/results.json), and [runner/lock revision details](VALIDATION.json)
record these assertions. All historical report blobs and the completed portable
and APB inputs, source locks, licences and attribution remain unchanged.

## Executed outcomes

| Target | Completed transactions | Accepted B / R | Independent comparisons | Resets / cancellations |
| --- | ---: | ---: | ---: | ---: |
| RTL slave | 274 | 74 / 200 | 1,577 | 7 / 5 |
| RTL master | 240 | 72 / 168 | 1,207 | 6 / 4 |
| Existing RTL integration | 208 | 72 / 136 | 1,044 | 4 / 2 |

Master CPU accounting: **244 requests = 240 completions + 4 cancellations**;
AW/W/AR accepted **74/74/169**, B/R accepted **72/168**. Integration:
**210 = 208 + 2**; AW/W/AR **73/73/137**, B/R **72/136**. The scoreboard and
runner independently enforce channel/response versus CPU/reset relationships.
The per-target `accounting.json` files and [validated counts](VALIDATION.json)
retain accepted-channel and accepted-response cancellation stages separately.

The 23 substeps comprise:

- **3 real-RTL UVM targets**, each with zero UVM errors/fatals and no unexpected
  assertion detections.
- **14 SVA controls**: 13 malformed traces, each with its individually expected
  detection; 1 legal trace with none. Response eligibility is checked at VALID,
  even with READY low, using pre-edge dependency state. See [case definitions](../../docs/DETERMINISTIC_AXIL_UVM.md#assertion-qualification).
- **6 request-oracle controls**: 2 legal reset/accounting traces and 4 legal-AXI
  duplicate-write/read traces across master/integration scoreboard modes.
  Each negative child wrapper returned **1** for its specific
  `REQUEST_DUPLICATE_WRITE` or `REQUEST_DUPLICATE_READ` fatal, with no SVA
  violation. The parent qualified those expected failures. Each legal child
  returned **0** with **58 CPU requests, 50 completions, 8 cancellations, 34 B
  and 18 R acceptances**. One accepted B and one accepted R were canceled before
  CPU completion, so 52 bus responses correctly coexist with 50 completions.

These synthetic controls test the checker, not a DUT. Functional counts,
qualification counts and procedural requirement hits are separate measures;
they are not functional coverage. Raw per-substep logs, accounting, requirement
hits and process exits are under [run/](run/). [Wrapper receipt](wrapper.json)
and [console](wrapper-console.log) preserve the actual top-level process result.

The [old-versus-corrected comparison and data/address/progress faults](../axil-uvm-corrective-2026-11-09/SUMMARY.md)
remain unchanged at corrected source `1263410134a27dda2c93741c3aa526001bf4469a`.
That report records four old-checker misses (exit 0), four corrected duplicate
rejections (exit 1), two legal passes, and five targeted data/address/progress
fault detections. This closeout reran the full 23-substep suite including the
corrected duplicate controls; the separate old-checker and data/address/progress
campaigns were **not rerun**. Their tested execution inputs match this merge.

## Tools, seed and captured bytes

Simulator: **Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025**. Matching installed UVM 1.2 library and
headers; runtime `QUESTA_UVM-1.2.3`. Python **3.14.3**; deterministic seed
**682016495 / 0x28A6BEEF**. Exact commands and version output are in
the JSON and [version.log](run/version.log). All 23 compiles report zero errors
and warnings. The counted simulation warning is `vopt-10908` from `+acc`;
the separate `onerror` macro-use warning also remains in the raw output.
Expected UVM fatals are retained in the four duplicate controls.

[Capture manifest](CAPTURE_MANIFEST.json): **121 artifacts** and
**9 VCDs**, copied without
changing a byte. Scoped `.gitattributes` `** -text` preserves original simulator
bytes, including CRLF. [Eight measured waveform figures](waveforms/MANIFEST.json)
come from the three actual RTL target captures; metadata records source revision,
exact byte hashes and tick ranges. These are measured samples, not expected
diagrams or delta-cycle analysis. No simulation behavior is attributed to newline
conversion. The included [audit utility](audit_bytes.py) checks Git blobs,
public raw VCDs and detached checkouts with both newline-conversion settings.

## Reproduce the merged source

The following paths were fresh for this execution. Choose unused source and
output paths for a rerun. Run one simulator session at a time. The single Python
command performs all 23 required substeps, including a fresh detached DUT clone:

```powershell
git clone --config core.longpaths=true --config core.autocrlf=false --branch main https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:/short/axil-uvm-merged-source-20261109
git -C C:/short/axil-uvm-merged-source-20261109 checkout --detach cdbb7b1d2e1ae73e621f9de884119c44b19efd99
Set-Location C:/short/axil-uvm-merged-source-20261109
& 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe' C:\short\axil-uvm-merged-source-20261109\scripts\run_axil_uvm.py --sim-bin C:/MXR/Quartus/25.1/questa_fse/win64 --uvm-lib C:/MXR/Quartus/25.1/questa_fse/uvm-1.2 --uvm-include C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src --output C:\short\axil-uvm-merged-results-20261109
if ($LASTEXITCODE -ne 0) { throw 'Required AXI4-Lite UVM/SVA substep failed or was blocked' }
```

## NOT RUN and remaining scope

**Functional coverage, constrained randomization and the original advanced
ALU/APB environments remain NOT RUN.** Preserved capability probes found their
required verification-feature licence unavailable; those probes were not rerun
here. No covergroup export, coverage percentage or coverage closure is claimed.

This remains the bounded 16-word, 32-bit, single-clock contract. The master
launches AW/W together and has no external B/R backpressure or completion-ready
input; integration retains its direct wiring. Overlapping read/write arbitration,
multiple outstanding requests, every parameter/reset permutation, all response
encodings, PROT policy, unknown-value stress, full protocol compliance, full
inherited SoC/ISA verification, synthesis, timing, FPGA and hardware remain
separate milestones. The completed eleven-project and deterministic APB releases
are preserved; Food Court and HDL-Design-Labs are untouched.
