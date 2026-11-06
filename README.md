# AMBA Protocol Verification

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
unstable payloads under backpressure, unmatched responses, invalid bounded
bursts, 4 KiB crossings, and last-beat errors. Four negative tests inject
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
separate monitor, executes nine simulations with 120-second timeouts, rejects
fatal/error logs even when a simulator exit happens to be zero, and writes
`results.json`. Any failed, blocked, or unexecuted required suite returns
nonzero. `scripts/run_portfolio_regression.ps1` and
`scripts/portfolio_suites.json` also retain the established nine-suite
portfolio regression entry point.

## Status and limits

This is portable, deterministic simulation rather than a UVM environment.
The checkers target implemented subsets, not complete protocol compliance.
The APB DUT has no wait states or error response; the AHB DUT uses a bounded
zero-wait response; AXI4-Lite tests one outstanding request through the
existing master; AXI4 tests the DMA's one-burst-at-a-time contract. No
functional coverage percentage, synthesis, timing, FPGA, or hardware result
is claimed. See [recorded results](docs/RESULTS.md),
[dependencies and attribution](docs/PROVENANCE.md), and
[licence status](LICENSE_STATUS.md).
