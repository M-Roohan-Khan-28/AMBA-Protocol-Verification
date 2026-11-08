# AMBA Protocol Verification

## Separate APB UVM milestone

The [APB advanced-verification guide](docs/ADVANCED_APB.md) describes a reusable
UVM 1.2 environment, two pinned real-DUT adapters, a synthetic wait-state target,
independent checking, concurrent assertions, deterministic tests and a separate
coverage-enabled mode. This work does not change the completed portable release
below. Functional coverage and constrained randomization require separately
qualified simulator features; a deterministic UVM pass is not coverage closure.

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
