# Merged-source deterministic DMA UVM/SVA closeout — 10 November 2026

## Merged and tested revisions

- [AMBA PR #12](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/pull/12), reviewed head `08bde7496be07c83c3acd546ecef6bc7e6cc40b5`,
  merged normally at **`54833a559d7afbc741c08f41f7df6b3dd24a2b52`**.
- [DMA documentation PR #4](https://github.com/M-Roohan-Khan-28/AXI4-DMA-Subsystem/pull/4), reviewed head `60d6b5862b3fc28e12202998a8046fa67be4ae12`,
  merged normally at `18f1a822da8ca00b5eb9b8a63c13d6e79123b6f1`; only README and adapter guide changed.
- Qualified implementation: `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d`. All **18 execution-input hashes** match
  that implementation and its reviewed PR head, before and after the merged run.
- Actual runner revision: `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d`.
- Actual inventory revision: `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d`.
- DUT locked and observed revision: `a2d3d57edaa9eb441f3289bf5320f4df2f074144`. The documentation
  merge does not repin tested RTL. [Source locks and hashes](SOURCE_LOCKS.json).

Owner CLI identity was `M-Roohan-Khan-28`, ID `270144410`; both reviewed heads
matched, with no reviews, unresolved threads, status checks or protection rules
blocking normal merge. Each merge used the reviewed full-SHA guard. Receipts
are under [source-receipts](source-receipts/). No force push or bypass occurred.

## Executed merged-source result

**47/47 required substeps PASS; aggregate exit 0; actual outer wrapper exit 0.**
A fresh ordinary GitHub clone was detached at the AMBA merge above and clean.
All simulator sessions, including child wrappers, executed serially.

| Category | Actual result |
| --- | --- |
| Standalone SVA | 30 PASS: 1 legal and 29 individually named expected-negative controls |
| Functional | 7 groups, 68 scenarios PASS (64 ordinary/legal-error/reset and 4 reset-isolated malformed-target cases) |
| Fault qualifications | 10 parent PASS; every child wrapper exited 1 for the intended condition |
| Source/accounting reconciliation | All 18 input hashes and all 68 per-case count records match the qualified corrective run |

Simulator: `Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025`; runtime `QUESTA_UVM-1.2.3`.
Seed: `0x28A6BEEF` / `682016495`. `vopt-10908` from `+acc` is the counted
optimization warning; the simulator also prints a separate `onerror` warning.
No crash, missing tool, timeout or unexpected fatal qualified as a pass.
[Raw logs/JSON](run/), [validation](VALIDATION.json),
[actual wrapper receipt](run/wrapper.json), [reproduction command](REPRODUCE.md).

## Resolved corrective findings

The WDATA oracle compares independently expected enabled lanes, retaining exact
WSTRB/LAST/progression, full offered-payload stability and protected-memory checks.
Seven legal changed-inactive-lane tail cases pass, including held partial writes.
Rejected CSR writes have complete SRC/DST/LENGTH/STATUS/ERROR/CONTROL readbacks
before overwrite/reset, including a paused busy responder and sticky status.
Both idle and busy side-effect mutations are detected by `CSR_READ`.
The immutable [old-versus-corrected evidence](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/blob/08bde7496be07c83c3acd546ecef6bc7e6cc40b5/reports/dma-uvm-corrective-2026-11-10/SUMMARY.md) preserves the old oracle's
seven false rejections and the old tests' two missed mutations. It is unchanged.

## Fault parents and actual child outcomes

| Fault | Parent | Child wrapper exit | Intended diagnostic |
| --- | --- | --- | --- |
| `fault-source_alias` | PASS | 1 | `ORACLE_AR_ADDRESS` |
| `fault-destination_progress` | PASS | 1 | `ORACLE_AW_ADDRESS` |
| `fault-active_data` | PASS | 1 | `ORACLE_WDATA` |
| `fault-tail_strobe` | PASS | 1 | `ORACLE_WSTRB` |
| `fault-duplicate_read` | PASS | 1 | `ORACLE_AR_OWNERSHIP` |
| `fault-duplicate_write` | PASS | 1 | `ORACLE_AW_OWNERSHIP` |
| `fault-progress` | PASS | 1 | `PROGRESS` |
| `fault-missing_marker` | PASS | 1 | `MISSING_RESULT_MARKER` |
| `fault-csr_idle_side_effect` | PASS | 1 | `CSR_READ` |
| `fault-csr_busy_side_effect` | PASS | 1 | `CSR_READ` |

The missing-marker child intentionally completes simulation without the required
wrapper marker; its nonzero result is not a simulator fatal. Other children
have the individually expected fatal and no unrelated simulation/assertion error.

## Accounting

90 accepted commands = 87 terminals + 3 reset cancellations; 87 terminals =
69 successes + 18 errors. All 102 rejected writes have completed readback
checkpoints. Every case, burst, beat and cancellation relationship is validated
by the runner and exactly matches the qualified corrective run.

| Counter | Actual total |
| --- | ---: |
| `commands` | 90 |
| `terminals` | 87 |
| `successes` | 69 |
| `errors` | 18 |
| `reset_cancellations` | 3 |
| `acknowledgements` | 86 |
| `control_rejected` | 102 |
| `control_cancelled` | 2 |
| `rejection_checkpoints` | 102 |
| `csr_reads` | 3,093 |
| `ar` | 164 |
| `aw` | 156 |
| `r_beats` | 1,682 |
| `w_beats` | 1,599 |
| `b` | 155 |
| `memory_commits` | 156 |
| `disabled_write_bytes` | 112 |
| `partial_write_stalls` | 25 |
| `comparisons` | 150,777 |
| `resets` | 77 |
| `cancelled_ar` | 1 |
| `cancelled_aw` | 1 |
| `cancelled_r_beats` | 18 |
| `cancelled_w_beats` | 16 |
| `cancelled_b_pending` | 1 |
| `aw_first` | 23 |
| `w_first` | 109 |
| `simultaneous` | 24 |
| `all_w_before_aw` | 34 |

`memory_commits` counts complete buffered write events, including the named
no-commit error-policy event; it is not a count of byte mutations. Counts have
different units and are not coverage percentages.

## Measured captures and byte policy

[Three measured crops](WAVEFORMS.md) are rendered from this run's actual VCDs;
the renderer validates pre-edge events before selecting each window.
[CAPTURE_MANIFEST.json](CAPTURE_MANIFEST.json) records exact captured bytes.
This report's scoped `** -text` preserves them, including CRLF. Figure captions
and metadata identify original simulator bytes and their SHA-256. No newline-only
difference is claimed to change simulation behavior. The later byte-audit receipt
checks Git blobs, public raw VCD downloads and fresh autocrlf-false/true checkouts.

## Preserved work and remaining limits

The original 43-substep and corrective 47-substep reports, completed eleven-project
release, APB/AXI4-Lite releases, source locks, licences and attribution remain
unchanged. The 40-case portable/11-file provenance results remain historical;
their inputs did not change, so they were not rerun for this closeout.

**Functional coverage, constrained randomization, and original licence-blocked
advanced ALU/APB environments: NOT RUN.** Procedural counts are not functional
coverage. Full AXI compliance, archived multichannel DMA, descriptors/scatter-gather,
peripheral handshakes, multiple outstanding/reordered traffic, arbitrary malformed
recovery, coverage closure, synthesis, timing, FPGA and hardware remain separate
milestones. Food Court and HDL-Design-Labs were untouched.
