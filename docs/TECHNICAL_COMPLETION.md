# Technical completion: locked eleven-project regression

The published runner commit is 35239784a519f163cb71104e088c952e3d4a69fc. Its inventory file was last changed in commit 30d041a59a043e49c1014274e53ad6ad37f31ea7. The inventory locks all eleven required project sources to full 40-digit commit SHAs; the AMBA self-suite uses source commit d85b82bc00ed9504d89a451114e465a0503779b9. The runner clones each repository afresh, checks out its lock detached, verifies the observed revision, and records the runner, script and inventory revisions and file hashes.

A clean GitHub clone of the AMBA technical branch ran the published runner with GitHub as the source for every required project. [Raw logs, JSON and summary](../reports/technical-completion-2026-11-07/portfolio-locked-remote/) record 11/11 required PASS, every required suite exit 0, a clean runner, all eleven revision matches, and aggregate exit 0. ModelSim Intel FPGA Starter Edition reported vsim 2020.1 Simulator 2020.02 Feb 28 2020. The two original advanced ALU/APB environments remain explicitly NOT RUN because the verification-feature licence is unavailable.

| Required suite | Observed result |
| --- | ---: |
| ALU exhaustive | 524,288 WIDTH=8 tuples, 1,579,002 comparisons; existing portable 1,380 checks also ran |
| APB interface | 2,697 contract checks, 673 accepted transfers; existing portable 1,317 checks also ran |
| APB modports | 12,488 contract checks; legacy 2 checks also ran |
| AHB-Lite RAM | 810 independent checks, including two-cycle ERROR response |
| Two-way cache | 1,639 independent checks; legacy 7 checks also ran |
| VGA SRAM | 29,588,940 public-pin comparisons across two full frames; legacy 7 checks also ran |
| Standalone AXI4-Lite | 7 functional tests |
| RV32I AXI4-Lite SoC | 24 runs |
| AXI4 DMA | 40 cases, 1,352,655 checks, seed 0x28A6BEEF |
| AMBA reusable verification | 11 internal simulations; corrected AHB and AXI4 DMA adapters |
| Coherent word memory | 71 subsystem scenarios; staged 135 and concurrent 106 core checks; additional bridge, reset/commit and shared-address cases |

The counts describe different test activities and are not combined coverage. The AMBA aggregate entry calls scripts/run_amba.ps1, not this portfolio runner. Its AHB driver handles the corrected two-cycle ERROR response. The AXI4 adapter observed 21 read and 21 write bursts, 315 beats each in its final monitor segment; the DMA bench resets that monitor between cases, so these are not totals for all 40 cases. Project-specific measured VCD and SVG figures are under each technical branch's reports/technical-completion-2026-11-07/; expected diagrams remain separately labelled.

## Measured waveforms

These SVG figures were rendered from actual simulator VCD captures; the source VCD and render notes are in the linked report folders. They illustrate selected cases, not exhaustive timing or hardware measurements.

- [ALU directed](https://github.com/M-Roohan-Khan-28/ALU-RTL-Verification/blob/technical/alu-exhaustive/reports/technical-completion-2026-11-07/passing/alu-directed.svg)
- [APB64 directed](https://github.com/M-Roohan-Khan-28/APB-Interface-Verification/blob/technical/apb64-contract/reports/technical-completion-2026-11-07/apb64-directed.svg)
- [APB modport boundary](https://github.com/M-Roohan-Khan-28/APB-Modports-Verification/blob/technical/apb-modports-contract/reports/technical-completion-2026-11-07/passing/apb-boundary.svg)
- [AHB ERROR phase](https://github.com/M-Roohan-Khan-28/AHB-Lite-RAM-Interface/blob/technical/ahb16-response-contract/reports/technical-completion-2026-11-07/ahb16-contract.svg)
- [Two-way cache](https://github.com/M-Roohan-Khan-28/Two-Way-Cache-RTL/blob/technical/cache-contract/reports/technical-completion-2026-11-07/passing/cache-contract.svg)
- [VGA horizontal interval](https://github.com/M-Roohan-Khan-28/VGA-SRAM-Framebuffer/blob/technical/vga-raster-contract/reports/technical-completion-2026-11-07/vga-raster.svg)
- [Standalone AXI4-Lite](https://github.com/M-Roohan-Khan-28/AXI4-Lite-Memory-Interface/blob/technical/response-order-qualification/reports/technical-completion-2026-11-07/measured-waveform/legal-selected.svg)
- [RV32I AXI4-Lite SoC](https://github.com/M-Roohan-Khan-28/RV32I-AXI4-Lite-SoC/blob/technical/response-order-qualification/reports/technical-completion-2026-11-07/corrected-qualification/measured.svg)
- [DMA W-before-AW](https://github.com/M-Roohan-Khan-28/AXI4-DMA-Subsystem/blob/technical/full-channel-ordering/reports/technical-completion-2026-11-07/wave-all_w_before_aw_16/dma-order.svg)
- [AMBA response-order negative](../reports/technical-completion-2026-11-07/response-fault-controls/original/measured.svg)
- [Coherent bridge](https://github.com/M-Roohan-Khan-28/RV32I-Coherent-Memory-SoC/blob/technical/commit-and-bridge-contract/reports/technical-completion-2026-11-07/wave-bridge/scenario.svg)
Reproduce the published locked run from a short, fresh path on Windows with Git and ModelSim Intel FPGA Starter Edition 2020.1 available:

~~~powershell
git -c core.longpaths=true clone --branch technical/response-order-qualification https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\amba-technical-reproduction
Set-Location C:\short\amba-technical-reproduction
git config core.longpaths true
git checkout --detach 35239784a519f163cb71104e088c952e3d4a69fc
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_portfolio_regression.ps1 -OutputDir C:\short\portfolio-technical-unique
if ($LASTEXITCODE -ne 0) { throw 'Required portfolio suite failed or was blocked' }
Get-Content C:\short\portfolio-technical-unique\results.json -Raw | ConvertFrom-Json | Select-Object aggregate_exit_code,runner_revision,inventory_revision,simulator_version
~~~

Use unused clone and output paths. The runner rejects missing tools, missing source revisions, dirty runner, failed or unexecuted mandatory suites, missing markers or simulation logs, simulator fatals, timeouts and count mismatches. A disposable impossible result marker produced [FAIL and aggregate exit 1](../reports/technical-completion-2026-11-07/fault-marker/); it did not alter source. Earlier development runs that failed because a local AMBA source clone was detached remain separate from the passing GitHub-source evidence.

Basic SystemVerilog and interfaces ran in the installed simulator. Class randomization and covergroups remain licence/feature blocked; an SVA probe did not execute its assertion, and no matching UVM library was configured. The original advanced ALU/APB suites are NOT RUN. This bounded milestone does not establish full inherited AXI/peripheral SoC behavior, complete RV32I ISA verification, coverage closure, full protocol compliance, synthesis, timing, FPGA or hardware operation. Historical reports and their source locks remain unchanged.
