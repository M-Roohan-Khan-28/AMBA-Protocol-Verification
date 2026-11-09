# DMA UVM/SVA focused corrective evidence — 10 November 2026

## Result and locked source

**47/47 required substeps PASS; actual aggregate and wrapper exits 0.**
This is a fresh detached GitHub environment and DUT run. Sessions are serial.
Both review PRs remain open and unmerged. Later evidence/documentation commits
are distinct from the tested implementation below.

| Input | Full tested revision |
| --- | --- |
| Environment | `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d` |
| Runner | `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d` |
| Inventory | `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d` |
| Unchanged DUT | `a2d3d57edaa9eb441f3289bf5320f4df2f074144` |

[Source locks and input hashes](SOURCE_LOCKS.json), [actual results](run/results.json),
[wrapper exit and command](run/wrapper.json), [validated accounting](VALIDATION.json),
and [one-command reproduction](REPRODUCE.md) are included. All 18 execution-input
hashes match the tested commit. The original [43-substep report](../dma-uvm-2026-11-09/SUMMARY.md)
is preserved unchanged, along with all earlier release evidence.

## Executed comparisons and qualification

| Control | Old implementation/tests | Corrected implementation/tests |
| --- | --- | --- |
| Legal changed inactive lanes, tails 1–7 | All seven falsely rejected with `ORACLE_WDATA`; wrapper 1 | Seven accepted; stalled partial payloads stable; memory/source/guard checks pass; wrapper 0 |
| Rejected idle partial-strobe SRC write silently modifies SRC | Mutation executed; old tests missed it, wrapper 0 | `CSR_READ`: expected `00023400`, observed `bad00000`; child wrapper 1 |
| Rejected busy SRC write silently modifies SRC, active transfer unchanged | Mutation executed; old tests missed it, wrapper 0 | `CSR_READ`: expected `00001080`, observed `dead0000`; child wrapper 1 |
| Active-byte corruption | Preserved historical evidence | `ORACLE_WDATA`, child wrapper 1 |
| Incorrect tail strobe | Preserved historical evidence | `ORACLE_WSTRB`, child wrapper 1 |

Raw old/new logs and JSON are under `targeted/`; each result records its own
source revision and hashes. The three old CSR test inputs exactly match reviewed
environment `e93a6fdff85804dab7b5e636e43880e1ba7615ab`. Mutated RTL bytes are
identical across old/new CSR comparisons and the final campaign; original lock
and mutated compiled hashes are separately recorded. Production RTL is unchanged.
The intermediate `targeted/new-lanes/` attempt was blocked before simulation by
the strict dirty-source guard while the edit was incomplete; it is not a pass.
The subsequent clean `new-lanes-v2` run passed. Full local validation then passed,
followed by the separate fresh GitHub run published here.

The data oracle uses its independently calculated mask to select enabled data
lanes. Exact observed WSTRB, WLAST, progression, full payload stability and
memory/source/guard obligations remain. The legal adapter changes only disabled
bytes and holds the transformed offer throughout stalls; all seven tails have
at least three observed partial-write stall edges. Acceptance logs compare
original and transformed enabled/disabled bytes independently in the runner.

Every rejected write is followed, before another write/reset/release, by reads
of SRC, DST, LENGTH, STATUS, ERROR and CONTROL. Expected register/state values
come from the passive public-pin CSR oracle. IRQ is checked continuously.
Checks cover initial idle state, sticky successful completion, sticky error,
and frozen-responder busy state. Busy transfers then complete normally.

## Full required inventory and real counts

- 30 standalone SVA controls: one legal and 29 individually named negative detections.
- 7 functional groups, 68 scenarios: 64 ordinary/legal-error/reset scenarios and four separately reset-isolated malformed-target cases.
- 10 qualified fault parents; all ten actual child wrappers exit 1 for their intended diagnostic. The original eight controls, including missing-marker, remain required.
- 150,777 independent comparisons; 90 commands = 87 terminals + 3 reset cancellations.
- 69 successes, 18 errors, 86 acknowledgements; 102 rejected CSR writes and 102 complete six-register readback checkpoints; 3093 accepted CSR reads.
- AR/AW 164/156; R/W beats 1682/1599; B acceptances 155; 156 completed buffered-write events.

Counts are separate units, not combined coverage. `memory_commits` denotes
complete buffered writes and includes the explicitly modeled no-commit error
policy event; it is not a count of modified memory bytes. The runner derives
the mandatory total from the inventory, reconciles each case and requires the
faults' corresponding positive controls. Missing tools, timeouts, crashes,
compile failures and unrelated fatals cannot qualify an expected-negative parent.

Simulator: `Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025`; runtime `QUESTA_UVM-1.2.3`;
deterministic seed `0x28A6BEEF` / 682016495. `vopt-10908` caused by `+acc` is
the counted simulator warning; the separate `onerror` warning remains in logs.

## Captures, preservation and limits

[Three measured corrective crops](WAVEFORMS.md) are rendered from real simulator
VCDs, with exact windows, original capture hashes and committed byte identity.
Scoped `** -text` preserves original bytes, including CRLF. No newline-only
simulation change is claimed. [Capture manifest](CAPTURE_MANIFEST.json) and
published-byte audit retain the original-versus-Git/raw/checkouts provenance.

The prior DMA portable result (40 cases / 1,352,655 checks) and 11-file archived
provenance remain in the unchanged original report. No RTL, portable runner or
relevant portable input changed, so they were not rerun. No shared APB/AXI4-Lite
code changed and no unrelated regression rerun is claimed. Prior releases,
source locks, upstream history, licences and M. Roohan Khan/Talib attribution
remain intact. Food Court and HDL-Design-Labs were untouched.

**NOT RUN:** functional coverage, constrained randomization and original
advanced ALU/APB environments, under the recorded feature/licence limitations.
No coverage percentage is inferred from counters. Archived multichannel DMA,
descriptors/scatter-gather, peripheral handshakes, multiple outstanding/reordered
traffic, arbitrary malformed-response recovery, full AXI compliance, coverage
closure, synthesis, timing, FPGA and hardware remain separate milestones.

## Published-byte verification

At evidence revision `b0e7e0bf48f87438ae9170451ec04a1ff510cfd6`, [BYTE_AUDIT.json](BYTE_AUDIT.json) verified
856 captured artifacts against Git blobs and fresh detached
checkouts with `core.autocrlf=false` and `true`. All 49 VCDs also
matched public raw downloads, and all 3 current figure metadata
and caption hashes matched the original capture bytes. The [audit command and
actual exits](BYTE_AUDIT_COMMAND.json) are recorded. This later receipt changes
no tested input, capture or historical evidence.
