# Deterministic AXI4 DMA UVM/SVA - review milestone, 9 November 2026

**43/43 required substeps PASS; actual aggregate and wrapper exits 0.**
The fresh detached GitHub environment was `e93a6fdff85804dab7b5e636e43880e1ba7615ab`, with clean worktree before
and after execution. Unmodified DUT lock: `a2d3d57edaa9eb441f3289bf5320f4df2f074144`. Runner last-change revision:
`e93a6fdff85804dab7b5e636e43880e1ba7615ab`; inventory revision:
`be4449ab5092a294c3be4b83b7bac0660e429530`. Later documentation, renderer and evidence
commits are separate from this tested implementation. PRs remain open for review.

## Executed inventory and accounting

| Class | Actual result |
| --- | --- |
| Standalone SVA controls | 30 PASS: 1 legal plus 29 individually named expected-negative detections |
| Ordinary/legal-error/reset functional group | 56 scenarios PASS; no unexpected assertion or UVM errors/fatals |
| Reset-isolated malformed responders | 4 PASS: wrong RID, wrong BID, early RLAST, missing final RLAST; each required its single intended assertion |
| Oracle/runner fault parents | 8 PASS; every child wrapper genuinely exited 1 for its intended cause |
| Existing DMA portable suite | 40 cases, 1,352,655 checks; wrapper/simulator exit 0 |
| Existing archived-source provenance | 11 files PASS at upstream `85868386f1d4c105b8baa666c5a6c273756fa8e5` |

The 60 functional scenarios recorded **132,158 independent comparisons**,
81 accepted commands = 78 terminal outcomes + 3 reset cancellations.
Terminal outcomes comprise 61 successes and 17 documented errors.
There were 30 rejected control writes, 2 partial-control cancellations,
77 acknowledgements and 2258 CSR reads. CSR reads are not completions.
Bus accounting: AR 149, AW 141, R beats 1561, W beats 1478,
accepted B 140, complete buffered write events 141 (including the explicit no-commit-error
policy case). Per-case JSON distinguishes canceled obligations and retained committed bytes.
Counts have different units and are not coverage percentages.

The scoreboard independently snapshots programmed source bytes, checks every
accepted burst/beat and compares destination/source/guard/protected bytes. The
runner reconciles each case with independent widened range/burst calculations.
See [validation](VALIDATION.json), [source locks](SOURCE_LOCKS.json),
[full raw run](run/results.json) and [requirements/contract guide](../../docs/DETERMINISTIC_DMA_UVM.md).

## Fault detection

| Test-only fault | Required diagnostic | Child wrapper exit |
| --- | --- | --- |
| `fault-source_alias` | `ORACLE_AR_ADDRESS` | 1 |
| `fault-destination_progress` | `ORACLE_AW_ADDRESS` | 1 |
| `fault-active_data` | `ORACLE_WDATA` | 1 |
| `fault-tail_strobe` | `ORACLE_WSTRB` | 1 |
| `fault-duplicate_read` | `ORACLE_AR_OWNERSHIP` | 1 |
| `fault-duplicate_write` | `ORACLE_AW_OWNERSHIP` | 1 |
| `fault-progress` | `PROGRESS` | 1 |
| `fault-missing_marker` | `MISSING_RESULT_MARKER` | 1 |

Fault shims are explicit in the tested adapter/responder; the DUT RTL is unchanged.
Each fault references its executed passing case. Duplicate controls repeat accepted
address/data/strobes unchanged after the original command completed. Their logs
require correct memory before the duplicate, bit-identical accepted traffic and
the specific ownership fatal. The progress fault must reach the command watchdog;
an OS timeout or compile error cannot qualify it. The missing-marker fault runs a
successful real-DUT case but demands an impossible marker, producing wrapper 1.
Fault parents reject unrelated assertion errors, simulator crashes and diagnostics.

## Tool execution and preserved development failures

The advanced run used **Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025**, `QUESTA_UVM-1.2.3`, seed
`0x28A6BEEF` (682016495), serial sessions, 90-second command bounds and a
2,400-second global bound. The counted optimization warning is `vopt-10908`
from `+acc`; the separate `Warning: onerror` command warning is also retained.
Expected UVM_FATAL fault detections are not unexpected suite failures. ModelSim
Intel FPGA Starter Edition `vsim 2020.1 Simulator 2020.02 Feb 28 2020` ran the
separate original portable suite. Raw commands and versions are preserved.

Development runs were executed in order: assertion controls, DUT smoke,
functional inventory, fault campaign, portable/provenance, then the locked clean
run. Two early smoke attempts failed compilation/elaboration (UVM override argument
name and multiply driven initial pin values); their logs remain under
[development](development/). A development duplicate-read attempt detected the
correct ownership fault, then Questa crashed on shutdown with SIGSEGV/exit 211.
The parent correctly rejected that run. Its separate fresh retry passed. The
first complete clean-clone attempt at `2638123be40cbb95262682f6c5e1b1d89c0ae7d5`
again rejected a shutdown SIGSEGV and then recorded three NOT RUN fault children
after GitHub connection/reset failures; aggregate and wrapper exited 1.
That report is preserved under `development/dma-uvm-final-run-20261109`.
Targeted comparisons qualified direct `-onfinish exit` shutdown. The new runner
uses it while retaining `+acc`; fault children make fresh detached, no-hardlink
local clones from the parent's verified clean GitHub DUT clone, checking its
origin and SHA first. The intermediate 40-substep complete run at
`6dfd0e1c2b970868206a5d2a0d9a666a73766b10` passed. Final checker review added AW/W same-edge LAST
reconciliation and three isolated LAST controls (same-edge, wrong early-W count, missing early-W
LAST). Targeted controls passed, then the complete expanded inventory passed at the final source
above.
This is a measured workaround, not a claim that all simulator shutdown bugs
are resolved. No crash or blocked run is relabelled as successful. During a later GitHub outage,
an explicitly recorded local-mirror run was intentionally stopped after access returned so the
final run could use fresh GitHub sources. Its partial results and wrapper exit 1 are preserved
separately; it is not a complete passing run. The published reproduction command does not require
the optional local-mirror argument.

## Measured waveforms and byte provenance

[Eight measured figures and capture guide](WAVEFORMS.md) derive directly from the
final functional VCD: address-first, data-first, all 16 W before AW,
simultaneous AW/first-W, destination boundary/tail, legal read error, committed
write followed by reset before B, and partial control-write reset. Each caption
and JSON identifies original simulator bytes, their SHA-256 and exact tick window.
The renderer independently verifies selected handshake events; figures are
illustrations, while scoreboards/assertions determine PASS. No expected waveform
is presented as a measurement. Delta cycles at one timestamp are collapsed by
the renderer and counted in metadata.

The scoped `.gitattributes` uses `** -text`: capture/log bytes, including CRLF,
are preserved without newline conversion. [CAPTURE_MANIFEST.json](CAPTURE_MANIFEST.json)
records each original artifact hash; `audit_bytes.py` checks Git blobs, public
raw VCD downloads and fresh detached checkouts with autocrlf false and true.
No newline-only change is attributed to simulation behavior.

## Reproduction and limits

[One-command execution after detached checkout](REPRODUCE.md) uses the published
source SHA and defaults of the qualified installation. All execution inputs and
their hashes are recorded. Missing tools/licences/markers, unexpected fatals,
timeouts or source mismatches fail the wrapper.

Functional coverage, constrained randomization and the original advanced ALU/APB
environments remain **NOT RUN**. No coverage closure is claimed. This is one
bounded programmed-command, fixed-ID, single-outstanding RAM DMA contract, with
shared reset and a well-behaved responder except explicitly classified controls.
Malformed RLAST recovery is bounded as documented, not arbitrary-stream draining.
Archived multichannel DMA, descriptors/scatter-gather, peripheral handshakes,
multiple outstanding/reordering, full AXI compliance, synthesis, timing, FPGA and
hardware remain separate milestones. Historical releases, inventories, licences
and M. Roohan Khan/Talib attribution are unchanged. No RTL correction was needed.
