# Separate deterministic AXI4-Lite UVM/SVA milestone

This environment is separate from the completed eleven-project portable release
and the merged APB UVM/SVA milestone. Their runners, inventories, source locks
and evidence are unchanged. The original RTL, licences and upstream attribution
remain in [AXI4-Lite-Memory-Interface](https://github.com/M-Roohan-Khan-28/AXI4-Lite-Memory-Interface).

## Three targets and independent checking

The full source lock is in [sources.json](../verification/axil_uvm/sources.json):
`faf43379b24a524999eb2c8ad7e100cde35054c3`. The runner clones that repository,
checks out the SHA detached, verifies the observed revision and clean tree,
and records SHA-256 hashes of every compiled RTL file. No vendor UVM source is
redistributed. The configuration uses the existing 32-bit RTL at base
`0x10000000`, with 16 SRAM words. This is a tested parameter configuration,
not a change to the default 1,024-word hardware.

| Adapter | Active UVM component | Actual target | Passive oracle |
| --- | --- | --- | --- |
| 0 | Initiator sequence/driver | Locked RTL slave plus SRAM | Byte-addressed memory model from public AW/W/AR/B/R pins |
| 1 | CPU-request driver and UVM responder | Locked RTL master | Accepted CPU request versus every AW/W/AR, response data/status and exactly-once CPU completion |
| 2 | CPU-request driver | Existing `axi4_lite_memory_top`, including its master/slave/SRAM | Same request and memory oracles, observing the top's public AXI interface pins |

The passive monitor samples a clocking block with `input #1step`. Drivers change
pins on falling edges. Reset is asserted between edges, held across clock edges,
then released away from sampling. No expected result reads DUT memory or internal
control state. Adapter 1's active responder uses a word memory; the independent
scoreboard uses a byte array and separate address arithmetic. The scoreboard
checks the master's bus addresses, data and strobes against the accepted CPU
request, and checks completion against the prior accepted bus response.
For master/integration, per-request AW/W or AR issue flags and the accepted
bus response remain associated with that CPU request until CPU completion or
reset cancellation. Clearing outstanding bus-channel state at a response does
not permit another transaction for the still-pending CPU request. A second
AW/W, AR or response is rejected even if its data and address are unchanged.

SRAM starts uninitialized. The sequences initialize all 16 words before any
checked read. Synchronous reset preserves memory. The oracle retains expected
bytes while dropping pending channel/request state. A slave write whose BVALID
was observed before reset remains committed even if BREADY had been low.
Partial AW-only/W-only writes must not commit. Master/integration cancellation
tests reset before a pending write issues or before a read response appears.

## Requirements exercised

| Requirement | Stimulus / checked result | Supported targets |
| --- | --- | --- |
| Independent AW/W | Address-first, data-first and simultaneous acceptance | Slave initiator; master with independently delayed READY |
| Stall stability | AW/W/AR and B/R VALID/payload held under stalls | Per-channel SVA; slave queued request under B backpressure; UVM responder's independent request stalls |
| Response eligibility | Check BVALID/RVALID regardless of READY, using pre-edge acceptance state | All targets; individually identified negative controls |
| Data/strobes | All 16 WSTRB masks, zero-strobe no-op, boundary/internal words, independent byte updates/readback | All targets |
| Addresses/errors | First/last words, below/above region, all three misalignment offsets, high alias and wrap boundary | All targets |
| Response backpressure | Held B and R with stable response data/status | Direct slave and legal SVA control |
| Pending reset | Partial AW/W, pending/held B, accepted AR, held R, retained memory/readback | Target-specific cases; no unsupported master backpressure control is invented |
| Bounded progress | At most 80 sampled cycles per driver transaction; simulation watchdog; wall timeout per process | All targets |
| Exactly once | Per-CPU request issue/response ownership; reconciled channel, response, CPU completion and reset counts; no leftover state | All targets; separate legal-AXI duplicate controls for master/integration oracle |

`requirements.json` records procedural requirement hits, not simulator functional
coverage. Missing required ordering, strobes, word readbacks, reset/error cases
or applicable stall observations are fatal. Reset cancellations and completed
transactions are recorded separately. The progress bounds are test assumptions,
not AXI latency limits.

`accounting.json` records independently sampled counts. Both the scoreboard and
Python runner enforce, separately for writes and reads:

- Accepted CPU requests = CPU completions + reset-canceled CPU requests.
- Accepted AW/W = completed CPU writes + the corresponding channels accepted
  by reset-canceled requests. Accepted AR uses the analogous read relationship.
- Accepted B/R = completed CPU writes/reads + responses already accepted for
  requests canceled before CPU completion.
- Reported driver completion/cancellation and log counts match those totals.

This explicitly permits reset after bus-response acceptance but before CPU
completion. The legal oracle controls exercise all eight cancellation stages:
write before either channel, AW-only, W-only, both before B, accepted B before
CPU completion; read before AR, accepted AR before R, accepted R before CPU
completion. Reset clears ownership once; memory remains retained.

## Assertion qualification

Thirteen malformed traces each run in their own reset-isolated simulation and must
produce exactly one named detection. A fourteenth legal trace must produce none.

| Case | Violation | Required detection |
| --- | --- | --- |
| 0 | AW payload changes while stalled | AW_HOLD |
| 1 | WSTRB changes while W is stalled | W_HOLD |
| 2 | AR address changes while stalled | AR_HOLD |
| 3 | BRESP changes while stalled | B_HOLD |
| 4 | RDATA changes while stalled | R_HOLD |
| 5 | BVALID with neither AW nor W accepted, BREADY low | B_ELIGIBILITY |
| 6 | BVALID after AW only, BREADY low | B_ELIGIBILITY |
| 7 | BVALID after W only, BREADY low | B_ELIGIBILITY |
| 8 | BVALID on the edge that accepts the missing W | B_ELIGIBILITY |
| 9 | RVALID before AR, RREADY low | R_ELIGIBILITY |
| 10 | RVALID on the same edge as AR acceptance | R_ELIGIBILITY |
| 11 | BVALID on the edge that accepts the missing AW | B_ELIGIBILITY |
| 12 | BVALID on the edge that accepts both AW and W | B_ELIGIBILITY |
| 13 | Legal three-way AW/W ordering and held B/R responses | No detection |

The eligibility properties consume nonblocking state updates from prior edges.
The independent scoreboard also checks response eligibility before processing
the current sampled frame's channel handshakes. Expected-negative simulations
are qualification results, not failing DUT transactions or coverage percentages.

## CPU-to-AXI oracle qualification

Six additional required simulations use the production passive monitor,
scoreboard, its full requirement/check phases, and the unchanged AXI SVA. They
drive a synthetic public-pin bus; they are **checker controls, not DUT runs**.
For each of master and integration scoreboard modes:

1. A legal control has 58 accepted CPU requests, 50 completions and 8 reset
   cancellations. It includes one accepted B and one accepted R canceled before
   CPU completion, so its 52 bus responses correctly exceed 50 CPU completions.
2. A duplicate-write control repeats a complete, legal, bit-identical AXI write
   after its first B response and before the one owning CPU request completes.
3. A duplicate-read control repeats a complete, legal, bit-identical AXI read
   in the equivalent window after its first R response.

No protocol-assertion violation or bad data is injected. The negative child
wrappers must return **1** for exactly `REQUEST_DUPLICATE_WRITE` or
`REQUEST_DUPLICATE_READ`, with zero SVA detections. The parent qualifies those
individual expected failures; missing results, wrong errors, timeouts or a
permissive wrapper exit 0 fail the required milestone. The same controls run
against the reviewed old package in a disposable worktree demonstrate its
misses; old source and raw comparison logs are retained separately.

## One-command execution

With Python, Git and the already qualified local Questa/UVM installation:

```powershell
& 'C:/Users/CG/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/run_axil_uvm.py --output C:/short/axil-uvm-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required AXI4-Lite UVM/SVA substep failed or was blocked' }
```

The output directory must not exist. The default full regression runs **23
required substeps**: three UVM targets, fourteen assertion qualifications and six
request-oracle controls, all **serially**. This Starter licence
allows one simulator session at a time. Defaults are:

```text
--sim-bin C:/MXR/Quartus/25.1/questa_fse/win64
--uvm-lib C:/MXR/Quartus/25.1/questa_fse/uvm-1.2
--uvm-include C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src
```

Override these flags together for a separately qualified installation. The runner
records the actual version, process commands, source revision/dirty state, input
hashes, source lock, seed `682016495` (`0x28A6BEEF`), statuses, counts and exit codes.
Missing tools/markers, wrong assertion IDs, simulator errors/fatals and timeouts
produce nonzero exit. A diagnostic selection never sets `milestone_pass=true`.
Missing accounting files, impossible reset stages or mismatched result-count
relationships also produce nonzero exit.

Each UVM simulation emits a real `capture.vcd`. The separate renderer accepts
only a successful full run and creates measured crops with exact byte hashes.
No expected diagrams are presented as simulator output.

## Fault controls and feature status

Explicit verification-boundary faults leave source RTL unchanged:

```powershell
& 'C:/Users/CG/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/run_axil_uvm.py --diagnostic-adapters 0 1 2 --fault data --output C:/short/axil-bad-data-new
& 'C:/Users/CG/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/run_axil_uvm.py --diagnostic-adapters 1 --fault address --output C:/short/axil-bad-address-new
& 'C:/Users/CG/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/run_axil_uvm.py --diagnostic-adapters 1 --fault drop-response --output C:/short/axil-no-response-new
```

These runs are expected to return **nonzero**. Data corruption must be caught
by the independent bus or CPU oracle; altered AWADDR by request checking; a
dropped read response by the bounded progress guard. Inspect the cause and
raw log, not just the exit code, to qualify a fault detection.

The focused request-oracle controls can also be executed individually:

```powershell
& 'C:/Users/CG/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/run_axil_request_control.py --adapter 1 --mode legal --output C:/short/axil-request-legal-new
& 'C:/Users/CG/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/run_axil_request_control.py --adapter 1 --mode duplicate-write --output C:/short/axil-request-duplicate-write-new
& 'C:/Users/CG/AppData/Local/Python/pythoncore-3.14-64/python.exe' scripts/run_axil_request_control.py --adapter 1 --mode duplicate-read --output C:/short/axil-request-duplicate-read-new
```

Use `--adapter 2` for the integration scoreboard mode. Legal returns 0;
duplicates must return 1 with their specific oracle fatal. These are diagnostic
child executions; only the full runner qualifies the complete 23-substep result.

Functional coverage and constrained randomization are **NOT RUN**. Prior real
[APB capability probes](../reports/advanced-apb-2026-11-08/SUMMARY.md) found the
`svverification` licence unavailable for those features. This deterministic
environment does not call `randomize()` or instantiate covergroups. The original
advanced ALU/APB environments remain **NOT RUN**. No functional coverage export
or percentage is claimed.

## Supported-contract limitations

This is bounded single-beat 32-bit AXI4-Lite verification. The master launches
AW/W together but can accept them in either order; it provides no external
B/R backpressure knob or completion-ready input. Its error mapping is exercised
with OKAY/SLVERR, not every possible response code. The integrated target uses
its existing direct wiring; artificial independent channel delays apply to the
separate master responder target. Overlapping reads/writes and SRAM arbitration,
multiple outstanding transactions, other memory depths, all reset/commit edge
permutations, PROT policy, unknown-value stress, full protocol compliance,
functional coverage closure, synthesis, timing, FPGA and hardware remain outside
this milestone. Existing portable tests remain separate evidence.
