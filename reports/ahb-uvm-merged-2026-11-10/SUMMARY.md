# Merged-source deterministic AHB UVM/SVA closeout - 10 November 2026

## Merged and tested revisions

| Item | Full revision |
| --- | --- |
| [AMBA PR #14](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/pull/14) merge and tested environment | `e58c30428d2a6348d3983c8ee3fbf9e1905629d2` |
| AMBA reviewed head | `e8eb02382c958a1297e2eb6811513b42336812b9` |
| [AHB documentation PR #3](https://github.com/M-Roohan-Khan-28/AHB-Lite-RAM-Interface/pull/3) merge | `66b37e1b21506c46ce7e1e68e582ffdc716a2c57` |
| AHB reviewed head | `c4d97499ed6b78b6859453b2d5b858b380f347c4` |
| Qualified implementation | `3eb0e520a880b2cfb13d304bbeea119dbe917fb3` |
| Runner last-change revision | `3eb0e520a880b2cfb13d304bbeea119dbe917fb3` |
| Inventory last-change revision | `33f33d6034165085833d5f16390f6a625d15a2bc` |
| Unchanged locked/observed DUT | `659fba67ce85a01643cceca2c8d1e67ea3903995` |

The owner CLI returned `M-Roohan-Khan-28`, immutable ID `270144410`.
Both PRs were non-draft and mergeable, with exact reviewed heads, no reviews,
unresolved threads, checks or active branch rules blocking the normal merges.
Each merge used its full reviewed-head guard. No force push or bypass occurred.
[Review and merge receipts](source-receipts/), [locks and hashes](SOURCE_LOCKS.json).
The AHB PR changed only README and two documentation files; DUT RTL is unchanged.

## Actual merged-source execution

**44/44 named required substeps PASS; aggregate exit
0; actual outer wrapper exit 0.**
The run used a fresh normal GitHub clone, explicitly detached at the actual AMBA
merge above. All simulator sessions ran serially. Environment and locked DUT
were clean before and after execution. All 23 execution-input hashes match the
qualified implementation, reviewed PR head, merged Git blobs and checkout bytes.

| Required category | Actual result |
| --- | --- |
| Runner qualification | 48/48 record-fixture checks PASS; one required substep |
| SVA controls | 23 PASS: 15 individually identified negative detections and 8 legal controls |
| Scoreboard controls | 6 PASS: 4 exact expected fatals and 2 legal/reset controls |
| Smoke and functional groups | 2 PASS; 45 HDL scenarios / 10,497 independent comparisons |
| Fault qualification | 11 parents PASS; each child wrapper exit 1, all three tool commands exit 0 |
| Portable AHB gate | 924 pin comparisons; 3 malformed-master detections and 1 legal hold; exit 0 |

Questa: `Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025`; runtime `QUESTA_UVM-1.2.3`.
Seed: `0x28A6BEEF` / `682016495`. The counted optimization warning is
`vopt-10908` from `+acc`; a separate printed `onerror` warning remains in the raw
logs. Neither is an assertion result. Tool/configuration fingerprints were
rechecked; proprietary vendor files are not redistributed.

[Raw logs and JSON](run/), [validated reconciliation](VALIDATION.json),
[tool-input fingerprints](VENDOR_INPUTS.json), [command-log hashes](COMMAND_HASH_AUDIT.json),
[actual wrapper receipt](run/wrapper.json), [one-command reproduction](REPRODUCE.md).
These are separate procedural measurements, not a coverage percentage.

## Runner correction resolved

The production fault predicate requires all vlib/vlog/vsim commands to finish
with exit 0 and no timeout, separately from child-wrapper exit 1, exact intended
diagnostics and source identity. The 48 fixture checks invoke that production
function and the exact historical guard AST from its locked source.
For both SVA fixtures, the old guard accepts substituted process exits 211, 127
and -11; the corrected guard rejects them. Missing exit fields expose the same
old gap. Original successful fault records still qualify; tool failures,
timeouts, incomplete commands, source mismatch and unrelated errors reject.
These are **synthetic record fixtures, not induced simulator crashes**.
[Actual fixture results](run/runner-qualification/run/results.json).

The unchanged [corrective report and old-qualifier failure control](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/blob/e8eb02382c958a1297e2eb6811513b42336812b9/reports/ahb-runner-correction-2026-11-10/SUMMARY.md) preserve
the earlier failed attempt, old/corrected comparisons and nonzero disposable
gate control. Those historical campaigns were not rerun or relabelled here.

## Preserved unsuccessful first run

The [first merged-source attempt](failed-first-run/results.json) returned aggregate
and actual outer wrapper exit **1**, not PASS. Windows power events record sleep
at `2026-11-10T01:49:36.203119500Z` and wake at `2026-11-10T13:37:23.174845600Z`.
The `fault-address_phase_data` child printed its intended `READ_DATA` diagnostic,
but its parent command timed out across the host sleep. The corrected predicate
rejected it; remaining work hit the global timeout and did not qualify.
[Original wrapper receipt](failed-first-run/wrapper.json) and
[Windows power-event evidence](failed-first-run/first-run-power-events.json) remain separate.
No executable source or timeout was changed. The complete serial run was repeated
from a second fresh detached clone at the same merge into a new output directory;
only that complete passing run is counted in the results above.

## Real fault outcomes

| Fault | Parent | Child wrapper | Exact intended diagnostic | vlib/vlog/vsim exits |
| --- | --- | ---: | --- | --- |
| `fault-live_address` | PASS | 1 | `READ_DATA` | `[0, 0, 0]` |
| `fault-address_phase_data` | PASS | 1 | `READ_DATA` | `[0, 0, 0]` |
| `fault-read_data` | PASS | 1 | `READ_DATA` | `[0, 0, 0]` |
| `fault-invalid_write` | PASS | 1 | `READ_DATA` | `[0, 0, 0]` |
| `fault-wait_advance` | PASS | 1 | `READ_DATA` | `[0, 0, 0]` |
| `fault-short_error` | PASS | 1 | `SVA:ERROR_FIRST` | `[0, 0, 0]` |
| `fault-missing_error` | PASS | 1 | `SVA:EP_ZERO_WAIT` | `[0, 0, 0]` |
| `fault-address_alias` | PASS | 1 | `ADDRESS_INTENT` | `[0, 0, 0]` |
| `fault-duplicate` | PASS | 1 | `UNSOLICITED_ADDRESS` | `[0, 0, 0]` |
| `fault-omit_observation` | PASS | 1 | `ADDRESS_INTENT` | `[0, 0, 0]` |
| `fault-missing_marker` | PASS | 1 | `MISSING_RESULT_MARKER` | `[0, 0, 0]` |

Every fault child's source/input identities match the parent and unchanged DUT.
Each has exactly three successful underlying tool commands, no timeout and no
unrelated error. The missing-marker child preserves genuine functional completion
but intentionally fails the required wrapper marker; it is not a simulator crash.
The original passing case for every mutation/shim executed in this full run.

## Functional accounting and portable gate

All 45 per-case results match the qualified corrective run exactly and reconcile:

```text
1896 offered = 1879 accepted + 16 withdrawn + 1 reset-unaccepted
1879 accepted = 1858 successful + 17 errors + 4 reset-accepted
1858 successful = 766 writes + 1092 reads
```

| Counter | Actual total |
| --- | ---: |
| `offered` | 1,896 |
| `accepted` | 1,879 |
| `success` | 1,858 |
| `errors` | 17 |
| `writes` | 766 |
| `reads` | 1,092 |
| `withdrawn` | 16 |
| `reset_accepted` | 4 |
| `reset_offered` | 1 |
| `wait_edges` | 65 |
| `pipeline_edges` | 1,700 |
| `resets` | 50 |
| `comparisons` | 10,497 |
| `cycles` | 2,322 |

Portable gate: 924 comparisons, 139 accepted, 135 retired, 40 commits, 12 errors
and 9 stalls; three malformed-master controls plus one legal hold.
Simulator: `Model Technology ModelSim - INTEL FPGA STARTER EDITION vsim 2020.1 Simulator 2020.02 Feb 28 2020`;
seed `0x28A81607`. Both portable simulator exits and its wrapper exit are 0.
The obsolete single-cycle ERROR legacy bench remains historical evidence.

## Capture bytes and historical figures

New raw VCDs belong to this merged execution. [CAPTURE_MANIFEST.json](CAPTURE_MANIFEST.json)
records their exact original capture hashes and those of the copied logs/JSON.
Scoped `** -text` preserves their original bytes, including any CRLF.
The byte-audit receipt added before the closeout PR records checks of Git blobs,
fresh detached checkouts with newline conversion disabled/enabled, and public
raw bytes for every included VCD.
No simulation-behavior difference is attributed to newline conversion.
The [existing measured figures](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/blob/faf8291b5d7b40362f30c79f12ed49453158dfc4/reports/ahb-uvm-2026-11-10/SUMMARY.md) stay linked to their original captures;
they are not labelled as figures from the new merged execution.

## Preserved releases and limits

The original AHB report, runner-correction report and development/failure records
are unchanged. Completed eleven-project, APB, AXI4-Lite and DMA releases retain
their runners, inventories, source locks and evidence. Licences, source history,
attribution, Food Court and HDL-Design-Labs are preserved.

**Functional coverage, constrained randomization and original licence-blocked
advanced ALU/APB environments: NOT RUN.** No required deterministic substep is
blocked. Full AHB compliance, HBURST/interconnect expansion, additional transfer
sizes, coverage closure, synthesis, timing, FPGA and hardware remain separate
milestones. The time bounds are test-environment assumptions, not AHB latency rules.
