# Deterministic AHB-Lite RAM UVM/SVA milestone

This separate milestone targets the public pins of the 16-word RAM at DUT lock
`659fba67ce85a01643cceca2c8d1e67ea3903995`. It does not replace the completed
APB, AXI4-Lite, DMA or eleven-project releases. The DUT RTL is unchanged.
`LICENSE_STATUS.md`, original notices and attribution remain applicable; no
new licence is assigned to the inherited design.

## Frozen contract and protocol references

The endpoint implements 16 32-bit words at aligned byte addresses 0x00–0x3C,
8-bit HADDR, word HSIZE=010, and selected NONSEQ/SEQ addresses accepted on
global HREADY. It saves address/control for the next data phase. Successful
transfers have zero **local** waits. Invalid size, alignment or range returns
a low-ready ERROR cycle followed by a high-local-ready ERROR cycle. That final
phase waits for global readiness. Invalid writes do not change RAM. Active-low
asynchronous reset cancels pending state and clears the entire RAM.

The [Arm AHB-Lite specification, IHI 0033A](https://documentation-service.arm.com/static/5f914801f86e16515cdc2a27)
provides the phase rules (§3.1–3.3), waited IDLE/BUSY exceptions (§3.6), ERROR
sequencing/cancellation (§5.1), and data-bus behavior (§6). There is no HBURST
port here. BUSY transition controls use the undefined-length sequence context;
they do not establish burst support. Full interconnect arbitration is absent.

Live HADDR/HWRITE/HSEL/HTRANS describe the *next* address, not the saved data
owner. Ignoring an unselected/IDLE/BUSY address does not cancel the preceding
accepted data phase. In particular, the old specification phrase “unselected
reads return zero” applies when there is no pending selected read; live HSEL=0
can coexist with a pending selected read returning its data. The tests retain
this distinction rather than changing RTL.

## Architecture and sampling

`ahb_item` carries named deterministic cycle controls and a separate request
intention (ID, address, direction, size, expected write data). `ahb_sequence`
sends these through a real UVM sequencer. The UVM driver coordinates overlapping
address and data cycles using a deterministic schedule for this fixed endpoint.
It publishes intentions before driving at the falling edge. No constrained
randomization or covergroup is needed. Xorshift-derived distinctive data uses
fixed seed `0x28A6BEEF`; Questa's explicit seed is `682016495`.

The harness produces `HREADY = external_ready && HREADYOUT`. The independently
controlled external stall does not override the local ERROR wait. This models
a bounded global stall, not a complete interconnect. Full-rate pipelines accept
a new address on the same edge that retires the preceding data phase. Independent,
same-address and arbitrary-address requests use NONSEQ; the seed/readback streams
use incrementing word SEQ continuations with unchanged direction/size. BUSY examples
reflect the next incrementing address before permitted continuation or termination.
Arm section 3.3 transfer-type rules guide this stimulus convention. With no HBURST input,
this is not a complete burst-operation verification target.

The passive monitor samples **only public pins**, with clocking-block input
`#1step` at the rising edge. Its scoreboard uses pre-edge ownership: retire
previous data, then accept the new selected address. It checks accepted address,
direction and size against queued intentions. Expected RAM is updated from the
intended write value at successful retirement, never from DUT internals or the
observed address. Public reads check that independent RAM model. Reset clears
both the model and accepted/unaccepted state. End-of-case accounting requires:

```
offered = accepted + withdrawn_speculative + reset_unaccepted
accepted = successful_retirements + error_retirements + reset_accepted
successful_retirements = successful_writes + successful_reads
```

No pending or queued request may remain. The runner independently validates each
actual per-case count against the named schedule's timing/accounting totals.
Those totals are not a second memory oracle. A duplicate transaction with no
new intention is rejected even if it would write the same value to the same word.
Cycle counters include all monitored active-case edges, including the initial
reset edge before the first driven schedule cycle in a simulation. Request and
retirement totals are validated separately. The test-only omission shim deliberately removes one observed address event;
normal monitor operation has no such omission.

## Assertions, legal exceptions and qualification

Concurrent SVA uses state updated by nonblocking assignments, retaining pre-edge
ownership for response dependency checks. Active waited addresses hold control;
waited IDLE may change address then become NONSEQ; BUSY may continue to SEQ or
end an undefined-length sequence with IDLE/NONSEQ. ERROR permits cancellation of
the speculative next address. Pending write data holds during waits; a pending
read may have changing HWDATA. Read data is checked at successful retirement,
without imposing AXI-style VALID/data rules.

`EP_ZERO_WAIT`, `EP_RESET`, and scoreboard `EP_ZERO_DATA` are stronger endpoint
contracts. Stable HSEL in an active global wait is a constraint of this simple
selected-endpoint harness. `GLOBAL_READY` checks the harness cannot override
local ERROR readiness. These are not claims about all AHB slaves/interconnects.
Every SVA negative has one precise expected diagnostic. Unexpected additional
assertion IDs fail. Standalone scoreboard negatives require their exact UVM
fatal, with no unrelated errors. Legal controls exercise the exceptions and
reset recovery before functional DUT traffic is used.

## Requirements matrix

| Requirement | Named tests | Independent checker / evidence |
| --- | --- | --- |
| Every word, overwrite, distinct neighboring data | `all_words_overwrite`; seed/readback in every non-smoke case | Intended-address checking, independent RAM, `READ_DATA` |
| Full-rate WW/WR/RW/RR, same and different addresses | eight `pipeline_*` cases | Pre-edge retire/accept; `WRITE_PAIR`; pipeline counts; measured pairing figure |
| NONSEQ/SEQ and ignored next addresses | seeded sequential streams; `ignored_unselected`, `ignored_idle`, `ignored_busy` | Prior data owner retained despite live control; readback |
| Global waits of 1/2/5 cycles with a different next address | six `wait_read_*`/`wait_write_*` | Address hold, saved owner, write hold, completion counts |
| Permitted waited exceptions | four `wait_idle/busy_*` cases; legal SVA controls | `IDLE_TRANSITION`, `BUSY_CONTROL`; changing read HWDATA legal |
| All seven unsupported sizes | `bad_size_0/1/3/4/5/6/7` | Independent invalid predicate; ERROR assertions; protected readback |
| Three misalignment classes and range boundaries | `bad_address_01/02/03/3d/40/80/fc`; `invalid_read` | Two-phase ERROR and zero-output endpoint checks |
| Speculative cancellation and continuation | invalid cases; `error_continue`, `error_final_held` | Named withdrawal, pre-edge owner, `ERROR_FIRST/SECOND/HOLD` |
| Reset clears RAM and cancels precisely | `reset_idle/normal/write_wait/error_first/error_finish` | Separate accepted/unaccepted cancellation; cleared public readback then successful write |
| Illegal phase/pairing/accounting | isolated checker `pairing/alias/duplicate/omitted` | Exact intended UVM fatal; legal/reset controls |
| False-rejection prevention | eight legal SVA controls, checker legal/reset | Read HWDATA changes; IDLE/BUSY exceptions; ERROR cancel/continue; clean reset recovery |
| Independent oracle sensitivity | seven separately compiled RTL mutations, address/observation/duplicate shims | Exact diagnostic plus nonzero child wrapper; original passing control |
| Runner fails closed | impossible mandatory marker | Genuine functional completion retained; child wrapper exit 1 |
| Existing corrected endpoint gate | `scripts/run_regression.ps1` in pinned DUT | Existing 924 pin comparisons and three malformed-master controls, separately reported |

## Execution and limitations

The milestone has its own `verification/ahb_uvm/sources.json`, inventory and
`run_ahb_uvm.py`. Full execution requires a clean committed environment and an
explicit full `--expected-env-sha`. Sources are freshly cloned and detached at
the full DUT SHA. Every simulator session is serial, with process and overall
bounds plus HDL watchdogs. Missing tools/licences, bad locks, missing markers,
unexpected fatals, timeout or failed mandatory substep yield nonzero wrapper
exit. `--select` is diagnostic and never sets `milestone_pass=true`.

Fault parents require a genuine nonzero child, matching environment/input hashes,
unchanged locked checkout and the exact intended diagnostic. A crash or compile
failure is not a qualified fault. Mutated RTL is compiled from a separate file;
the original source remains clean. Mutation diffs and original/compiled hashes
are recorded. Wait-advancement fault detection concerns observable public
behavior, not an invisible idempotent internal write.

Functional coverage, constrained randomization and the preserved original advanced
ALU/APB environments are **NOT RUN**. Directed requirement observations are not
coverage closure. Full AHB compliance, HBURST/interconnect expansion, additional
sizes, synthesis, timing, FPGA and hardware remain separate milestones.

See the new milestone report for actual results, exact tested source, complete
logs, fault evidence, byte-preserved VCDs, measured figures and reproduction.

The process and HDL watchdog bounds are test-environment assumptions, not AHB
protocol latency limits. The recorded Questa counted warning is `vopt-10908`
from `+acc`; the separate `onerror` macro warning is also preserved in raw logs.
Neither warning is an assertion result.

## Qualified execution after runner correction

Environment `3eb0e520a880b2cfb13d304bbeea119dbe917fb3`; unchanged DUT `659fba67ce85a01643cceca2c8d1e67ea3903995`.
The [separate corrective report](../reports/ahb-runner-correction-2026-11-10/SUMMARY.md) records 44/44 required PASS,
actual wrapper exit 0. The added required runner qualification has 48 record-fixture
checks; it is separate from 45 HDL functional scenarios / 10,497 comparisons,
23 SVA controls, six scoreboard controls, 11 fault parents and the portable gate.
All fault kinds require tool exits 0, expected child-wrapper exit 1 and their exact
diagnostic. An abnormal simulator exit cannot qualify based on assertion text.
The original [43-substep report and measured figures](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/blob/faf8291b5d7b40362f30c79f12ed49453158dfc4/reports/ahb-uvm-2026-11-10/SUMMARY.md) remain historical evidence.
The qualification imports the production predicate and executes old guard AST from
the locked original runner; modified records are not actual simulator crashes.

Choose unused paths with the qualified Questa/UVM installation and separate ModelSim
2020.1 portable gate. Coverage/randomization/original advanced ALU/APB remain NOT RUN.

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\ahb-corrected-source-new
git -C C:\short\ahb-corrected-source-new checkout --detach 3eb0e520a880b2cfb13d304bbeea119dbe917fb3
& $python C:\short\ahb-corrected-source-new\scripts\run_ahb_uvm.py --expected-env-sha 3eb0e520a880b2cfb13d304bbeea119dbe917fb3 --output C:\short\ahb-corrected-output-new
if ($LASTEXITCODE -ne 0) { throw 'Required AHB milestone failed or was blocked' }
```

## Merged-source closeout - 10 November 2026

[AMBA #14](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/pull/14) merged at `e58c30428d2a6348d3983c8ee3fbf9e1905629d2`;
[AHB documentation #3](https://github.com/M-Roohan-Khan-28/AHB-Lite-RAM-Interface/pull/3) merged at `66b37e1b21506c46ce7e1e68e582ffdc716a2c57`.
The [new merged-source report](../reports/ahb-uvm-merged-2026-11-10/SUMMARY.md)
records **44/44 named required PASS**, aggregate/outer wrapper exit 0, from a fresh
clean detached GitHub clone. All 23 execution hashes match qualified `3eb0e520a880b2cfb13d304bbeea119dbe917fb3`.
Runner `3eb0e520a880b2cfb13d304bbeea119dbe917fb3` and inventory `33f33d6034165085833d5f16390f6a625d15a2bc` remain distinct;
DUT `659fba67ce85a01643cceca2c8d1e67ea3903995` is unchanged. The abnormal-process-exit runner defect is resolved.
The new 48 fixture checks, 45 HDL scenarios / 10,497 comparisons, 23 SVA,
six scoreboard controls, 11 strict fault parents and portable 924-comparison gate
all passed. Every fault child exits 1 with three tool exits 0 and no timeout.
All request/retirement/reset accounting matches the qualified corrective run.
[Reproduce this actual merge](../reports/ahb-uvm-merged-2026-11-10/REPRODUCE.md).
Earlier commands above reproduce their separately labelled historical evidence.
All historical reports, prior releases, NOT RUN statuses and scope limits remain.
