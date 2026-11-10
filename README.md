# AMBA Protocol Verification

## Separate deterministic AXI4 DMA UVM/SVA milestone

The [DMA contract and requirements guide](docs/DETERMINISTIC_DMA_UVM.md) describes
the UVM control initiator, early-W-buffering responder and independent public-pin
oracle. The [merged-source closeout](reports/dma-uvm-merged-2026-11-10/SUMMARY.md)
records **47/47 required PASS** at merge `54833a559d7afbc741c08f41f7df6b3dd24a2b52`:
30 SVA controls, seven groups / 68 scenarios, and ten qualified faults whose
children each exit 1. Aggregate and outer wrapper exit 0; all 18 execution inputs
match the reviewed corrective implementation. Both milestone PRs are merged.
[Reproduce](reports/dma-uvm-merged-2026-11-10/REPRODUCE.md) with a normal clone
and explicit detached merge SHA. New captures retain exact byte provenance.
The [old/new corrective controls](reports/dma-uvm-corrective-2026-11-10/SUMMARY.md),
original 43-substep report, portable evidence and completed releases are unchanged.
Functional coverage, constrained randomization and original advanced ALU/APB
remain **NOT RUN**; the bounded contract and physical-implementation limits remain.

## Separate deterministic AXI4-Lite UVM/SVA milestone

The [AXI4-Lite UVM guide](docs/DETERMINISTIC_AXIL_UVM.md) documents three
locked-RTL targets: UVM initiator against slave, UVM responder against master,
and the existing integration. Independent public-pin scoreboards, pre-edge
response eligibility assertions, individually qualified negative controls and
bounded fault detection run serially. Coverage and randomization are NOT RUN.
The completed portable and APB UVM milestones below remain unchanged.
The [corrected fresh-clone results and raw evidence](reports/axil-uvm-corrective-2026-11-09/SUMMARY.md)
record 23 required substeps PASS, legal-AXI duplicate controls that expose the old
request oracle, and five rerun data/address/progress fault detections. The
[earlier 17-substep evidence](reports/axil-uvm-2026-11-08/SUMMARY.md) remains unchanged.


The [merged-source closeout](reports/axil-uvm-merged-2026-11-09/SUMMARY.md)
records a new 23/23 serial pass from AMBA merge `cdbb7b1d2e1ae73e621f9de884119c44b19efd99`,
actual wrapper exit 0, unchanged DUT lock and reconciled CPU/bus/reset accounting.
Both reviewed milestone PRs are merged; prior controls and reports are preserved.

## Separate APB UVM milestone

The [APB advanced-verification guide](docs/ADVANCED_APB.md) describes a reusable
UVM 1.2 environment, two pinned real-DUT adapters, a synthetic wait-state target,
independent checking, concurrent assertions, deterministic tests and a separate
coverage-enabled mode. This work does not change the completed portable release
below. Functional coverage and constrained randomization require separately
qualified simulator features; a deterministic UVM pass is not coverage closure.
The [new raw evidence and summary](reports/advanced-apb-2026-11-08/SUMMARY.md)
record three UVM adapter passes, five expected assertion detections and one
legal assertion control from a clean detached clone. Covergroups and the two
original advanced ALU/APB environments remain **NOT RUN** for the licence blocker.

## Latest merged-main technical release — 8 November 2026

The [locked merged-main technical release](reports/technical-release-2026-11-08/RELEASE_SUMMARY.md) records eleven required project suites PASS from fresh detached GitHub source clones at runner `9820035daf9a63f5bbf4fa14c2621a65a746cd85`, aggregate exit 0. AXI4-Lite and RV32I SoC each require a separate checker qualification with one legal case and eight expected-negative detections. The preserved original advanced ALU/APB environments remain **NOT RUN** for the unavailable `svverification` licence.

Reusable transaction types, portable drivers, passive protocol monitors, and
separate DUT adapters for four bounded
interfaces: the 64-word APB RAM, 16-word AHB-Lite RAM, 32-bit AXI4-Lite SRAM
path, and single-channel 64-bit AXI4 DMA. The adapters run against pinned
public source revisions; this repository does not replace or alter those DUTs.
The APB, AHB-Lite, and AXI4-Lite adapters use typed transactions and driver
modules. A configurable APB RAM responder exercises wait states and an error
address; the AXI4 adapter reuses the DMA bench's deterministic stall/error
responder and independent byte-memory oracle.

The monitors count accepted transfers and detect selected illegal sequencing,
unstable payloads under backpressure, unmatched responses even while READY
is low, legal write-data-before-address ordering, invalid bounded bursts,
4 KiB crossings, and last-beat errors. Six negative tests inject
specific violations and require the same monitors to detect them. The
positive adapters use independent memory/reference models (or, for AXI4,
the DMA project's independent byte-memory oracle) and compare observed
architectural results. See [the verification matrix](docs/VERIFICATION_MATRIX.md)
and [scope](docs/SPECIFICATION.md).

## Reproduce

Windows PowerShell, Git, network access to the public DUT repositories, and
ModelSim Intel FPGA Starter Edition 2020.1 are needed. From this repository:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_amba.ps1 -OutputDir <fresh-output-directory>
```

The runner clones four pinned DUT revisions, compiles each adapter with its
separate monitor, executes eleven simulations with 120-second timeouts, rejects
fatal/error logs even when a simulator exit happens to be zero, and writes
`results.json`. Any failed, blocked, or unexecuted required suite returns
nonzero. `scripts/run_portfolio_regression.ps1` and
`scripts/portfolio_suites.json` provide the locked eleven-project-suite
portfolio regression entry point. Its [locked revisions, raw results and
reproduction command](docs/PORTFOLIO_REGRESSION.md) are documented separately.
The [technical completion run](docs/TECHNICAL_COMPLETION.md) locks the new
eleven-project branch revisions and records a fresh GitHub-source 11/11 pass.
Its [separate follow-up evidence](reports/technical-completion-2026-11-08/portfolio-locked-followup/SUMMARY.md)
locks the AHB master-wait checks and VGA measured boundary captures; the
aggregate still reports each project's checks separately.
The [measured protocol trace guide](docs/PROTOCOL_WAVEFORMS.md) links raw
APB wait/error, AHB write/ERROR and reset-isolated AXI response-order VCDs.

## Status and limits

This is portable, deterministic simulation rather than a UVM environment.
The checkers target implemented subsets, not complete protocol compliance.
The APB DUT has no wait states or error response; the AHB DUT uses a bounded
two-cycle ERROR response for invalid transfers. AXI4-Lite tests one outstanding
request through the existing master; AXI4 tests the DMA's one-burst-at-a-time
contract. No
functional coverage percentage, synthesis, timing, FPGA, or hardware result
is claimed. See [recorded results](docs/RESULTS.md),
[dependencies and attribution](docs/PROVENANCE.md), and
[licence status](LICENSE_STATUS.md).

The reset-isolated AXI4 response-order test, its separate B/R fault controls,
measured VCD figure, and the fresh 11/11 internal simulation result are in
[response-order qualification](docs/RESPONSE_ORDER_QUALIFICATION.md). These
are bounded monitor tests; the original advanced ALU/APB environments remain
NOT RUN without their verification-feature licence.

## Separate deterministic AHB-Lite RAM UVM/SVA milestone

The [bounded environment](docs/DETERMINISTIC_AHB_UVM.md) passed 44 required substeps
from fresh detached clones: 48 runner-fixture checks, separately reported from
45 HDL scenarios / 10,497 comparisons, 23 SVA controls, six scoreboard controls,
11 qualified fault parents and the current portable gate.
[Corrective evidence and reproduction](reports/ahb-runner-correction-2026-11-10/SUMMARY.md) records the common
process-exit guard, old/new fixture proof, tool exits and exact source locks.
Prior releases and measured figures remain intact. Coverage, randomization and
original advanced ALU/APB remain NOT RUN.
