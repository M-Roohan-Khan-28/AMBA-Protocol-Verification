# AXI4-Lite request-to-transaction oracle correction - 9 November 2026

**23/23 required substeps PASS; project/aggregate and actual wrapper exit 0**
from a fresh detached GitHub clone. This is a corrective continuation of open
AMBA PR #10 and AXI4-Lite adapter documentation PR #3, not a merged release.
The original 17-substep report remains [historical evidence](../axil-uvm-2026-11-08/SUMMARY.md).
The old checker missed duplicate bus transactions in the window after an
accepted B/R response and before CPU completion; the controls below expose it.

## Exact sources and preservation

- Reviewed AMBA starting head: `49d41c5859fd8a5111ee3ba19735d32fe4a6134e`.
- Reviewed adapter-documentation head: `cb9b9e3526469d31065fc57100da11c36e2b870b`.
- Corrected tested implementation, runner, count validator and control source:
  **`1263410134a27dda2c93741c3aa526001bf4469a`**. This source stayed clean and detached during
  the full run and all affected fault campaigns. Later documentation/evidence
  commits do not change the tested inputs.
- Unchanged actual DUT lock: **`faf43379b24a524999eb2c8ad7e100cde35054c3`** in
  `M-Roohan-Khan-28/AXI4-Lite-Memory-Interface`. The runner fetched fresh DUT
  clones, checked observed/expected full revisions and clean state, and recorded
  hashes of all five RTL files. No DUT RTL is modified.
- AMBA main remains `d826c798bc7c1d07204a2db414128f6f0774d0fe`; no merge is made.
  [Preservation checks](PRESERVATION.json) retain prior APB/portable runners,
  source locks, licences, attribution and historical reports unchanged.

## Corrected association and accounting

Each accepted CPU request owns sticky AW/W or AR issue flags and its accepted
bus response until CPU completion or reset cancellation. Outstanding AXI channel
flags may clear at B/R acceptance; CPU ownership does not. A second bus issue
or response is rejected even when the address/data match. VALID response
eligibility still uses pre-edge state and is checked while READY is low.

The scoreboard and Python runner independently reconcile accepted CPU requests,
completed CPU requests, reset cancellations, accepted AW/W/AR and accepted B/R.
For example, accepted B equals completed CPU writes plus B responses already
accepted for reset-canceled CPU writes. Separate cancellation counters retain
which channel/response stages each canceled request reached. Missing accounting
or mismatched relationships fail the wrapper. See the [current guide](../../docs/DETERMINISTIC_AXIL_UVM.md).

## Targeted old-versus-corrected controls ran first

[Ten targeted executions](targeted-results.json) ran serially before the full
regression: six corrected controls and four old-checker comparisons. The old
package in a disposable detached worktree matches its reviewed Git blob exactly:
SHA-256 `880ca57c811e2e2f55dded6b7ca6c64b5827908a108f5cffde01f9ac5e85af03`.
Only the new control harness and wrapper/count-validator files were added to
that worktree; their hashes match the corrected test's files. No old checker
assertion or requirement gate was disabled or rewritten.

The synthetic public-pin control uses the production passive monitor,
scoreboard and its full check phase, with the existing SVA. No DUT is instantiated.
It first initializes/reads all words, exercises all masks and required ordering,
error and stall cases, and performs eight reset cancellations. The duplicate
then repeats the same legal AXI transaction with unchanged address, data and
strobes, after the first bus response but before the single CPU completion.
These are checker qualifications, not extra DUT functional transactions.

| Scoreboard mode | Duplicate | Old checker / wrapper | Corrected checker / wrapper |
| --- | --- | --- | --- |
| Master (1) | Write | Missed; **0** | REQUEST_DUPLICATE_WRITE; **1** |
| Master (1) | Read | Missed; **0** | REQUEST_DUPLICATE_READ; **1** |
| Integration (2) | Write | Missed; **0** | REQUEST_DUPLICATE_WRITE; **1** |
| Integration (2) | Read | Missed; **0** | REQUEST_DUPLICATE_READ; **1** |

All four old runs reach their positive completion marker, with zero AXI
assertion detections and no bad-data error. They have 59 accepted CPU requests,
51 completions and eight cancellations. Duplicate-write reports 36 B and 18 R
responses; duplicate-read reports 34 B and 20 R responses. Each includes one
extra response beyond the reset-adjusted one-request/one-transaction totals.
The corrected runs reject the second AW or AR and print no positive marker.
Each child simulator process returns 0 after UVM fatal handling, but its wrapper
returns **1** after validating the real log. Raw logs/VCDs and individual
`QUALIFICATION.json` files are under `targeted/`.

The corrected legal control passes in both modes: **58 CPU requests, 50
completions, eight cancellations, 34 B and 18 R acceptances**. Its one accepted
B and one accepted R canceled before CPU completion explain 52 bus responses
versus 50 CPU completions. Other reset stages cover write before either channel,
AW-only, W-only, both before B, read before AR and accepted AR before R.
The first corrected duplicate-write run on 8 November is preserved separately
under `first-target-2026-11-08/`; it is not an additional required suite.

## Fresh-clone complete milestone

[Fresh-clone receipt](fresh-results.json), [full JSON](full/results.json),
[actual wrapper receipt](full/WRAPPER_RESULT.json) and [console](full-console.log)
record the actual commands, clean revision, seed, tool and exit codes.

| Real RTL target | Completed transactions | B / R responses | Independent comparisons | Resets / cancellations |
| --- | ---: | ---: | ---: | ---: |
| RTL slave | 274 | 74 / 200 | 1,577 | 7 / 5 |
| RTL master | 240 | 72 / 168 | 1,207 | 6 / 4 |
| Existing RTL integration | 208 | 72 / 136 | 1,044 | 4 / 2 |

Master accounting: 244 accepted CPU requests = 240 completions + four reset
cancellations; accepted AW/W/AR = 74/74/169, accepted B/R = 72/168.
Integration accounting: 210 = 208 + two cancellations; accepted AW/W/AR =
73/73/137, accepted B/R = 72/136. Per-target `accounting.json` files expose the
write/read and cancellation-stage breakdowns; the runner checked them.

The **23 required substeps** are three UVM DUT targets, fourteen existing SVA
qualifications (13 individually expected detections plus one legal trace), and
six request-oracle qualifications (two legal plus four expected duplicate
rejections). The parent accepts only each named expected fatal and child exit 1
for a negative oracle control; missing results, unexpected errors, wrong IDs,
timeouts, or old-checker exit 0 fail the full run. Functional, assertion and
checker-control counts are separate measures, not coverage percentages.

## Affected fault campaigns rerun from the same fresh source

| Fault | Required observed cause | Actual wrapper exit |
| --- | --- | ---: |
| [Read data, all three targets](fault-data/FAULT_QUALIFICATION.json) | ORACLE_DATA / CPU_DATA / CPU_DATA | **1** |
| [Master AW address](fault-address/FAULT_QUALIFICATION.json) | REQUEST_ADDRESS | **1** |
| [Dropped master read response](fault-progress/FAULT_QUALIFICATION.json) | PROGRESS | **1** |

All five faulted simulations were rejected for the intended reason, with no
positive result marker. Simulator process exits were 0; the wrappers correctly
converted the fatal logs to nonzero. Faults affect verification-boundary signals,
not source RTL. This evidence is separate from the passing full run.

## Tools, measured traces and byte policy

Simulator: **Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025**. Matching installed UVM 1.2
library/headers, runtime `QUESTA_UVM-1.2.3`; seed **682016495 / 0x28A6BEEF**.
Sessions ran serially. Compiles report zero errors/warnings. Simulation logs
retain the counted `vopt-10908` warning from `+acc` and the separate `onerror`
macro-use warning. Expected UVM fatals appear only in the qualified negative and
fault runs; they are not hidden from the archived output.

The [capture manifest](CAPTURE_MANIFEST.json) maps **260**
archived artifacts to original paths and exact hashes. Scoped `-text` preserves
original capture bytes, including CRLF. [Ten measured figures](waveforms/MANIFEST.json)
include eight from the corrected full DUT run and two from the old synthetic
duplicate controls. The latter are explicitly labelled synthetic: they show
legal AXI reuse that violates CPU request association. All are actual simulator
samples, not expected diagrams; same-timestamp rendering is not delta-cycle
analysis. Metadata identifies the source representation, checker/control source
revisions, hashes and tick ranges. Public-byte verification is recorded after
the evidence push. No behavior change is attributed to newline differences.

## Reproduce the corrected full run

Choose unused short paths and run one simulator session at a time:

```powershell
git clone --config core.longpaths=true --config core.autocrlf=false --branch advanced/axil-deterministic-uvm https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:/short/axil-correct-reproduce-source
git -C C:/short/axil-correct-reproduce-source checkout --detach 1263410134a27dda2c93741c3aa526001bf4469a
python C:/short/axil-correct-reproduce-source/scripts/run_axil_uvm.py --output C:/short/axil-correct-reproduce-results
if ($LASTEXITCODE -ne 0) { throw 'Required AXI4-Lite UVM/SVA substep failed or was blocked' }
```

Defaults select `C:/MXR/Quartus/25.1/questa_fse/win64`, its `uvm-1.2` library
and `verilog_src/uvm-1.2/src` headers. The JSON records the exact resolved Python
interpreter and executed command. Individual control commands are in the guide;
legal controls return 0, duplicates must return 1 with their specified cause.
For the old-checker comparison, make a disposable worktree detached at
`49d41c5859fd8a5111ee3ba19735d32fe4a6134e`, copy only
`verification/axil_uvm/axil_request_control.sv`,
`scripts/run_axil_request_control.py` and `scripts/axil_accounting.py` from the
tested corrected source, and run each duplicate mode with adapters 1 and 2.
The old wrapper's exit 0 is a demonstrated miss, not a passing qualification.
`targeted-results.json` preserves the exact executed commands and package hashes.

## NOT RUN and scope limits

Functional coverage, constrained randomization and the original advanced
ALU/APB environments remain **NOT RUN**. Preserved real probes found their
required verification-feature licence unavailable; those probes were not rerun.
No covergroup execution/export or functional coverage percentage is claimed.
Procedural counters are not functional coverage.

This remains a bounded 16-word, 32-bit, single-clock milestone. The master
launches AW/W together and has no external B/R backpressure or completion-ready
input; the integration retains its original wiring. Overlapping read/write
arbitration, multiple outstanding requests, every parameter/reset permutation,
all response encodings, PROT policy, full protocol compliance, coverage closure,
full inherited SoC/ISA, synthesis, timing, FPGA and hardware remain separate.
The completed eleven-project release and merged deterministic APB milestone are
unchanged; no new eleven-project aggregate is claimed. Both current PRs remain
open for review.
