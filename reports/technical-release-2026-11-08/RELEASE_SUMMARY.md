# Technical release: merged-main locked regression — 8 November 2026

The detached, clean AMBA runner at `9820035daf9a63f5bbf4fa14c2621a65a746cd85` cloned all eleven required project sources from GitHub at the full-SHA locks below. All eleven required suites passed with individual exit 0; aggregate and wrapper exit 0. The two preserved original advanced ALU/APB environments are **NOT RUN** because the `svverification` licence is unavailable.

Simulator: `Model Technology ModelSim - INTEL FPGA STARTER EDITION vsim 2020.1 Simulator 2020.02 Feb 28 2020`.
Runner script revision: `d6a0c6129eee66e05cc19f67a6341e4ed6acec24`.
Inventory revision: `bc9197700d29e1e7291adf78975d8eaa1ce04acb`.
Inventory SHA-256: `D55696EB9A301BC3A17A195BE1B4A9FE1CF88DC32EE6DB565F6CD0C8ED7A3CC0`.
AMBA source lock: `c5f75cb35b95b3f43da4da44e65df3ec675fb17e`; AMBA internal simulations: 11/11, exit 0.

| Required suite | Merged source SHA | Functional result | Checker qualification | Exit | Seed |
| --- | --- | --- | --- | ---: | --- |
| alu-exhaustive | `d87cb160e86f50f74b2836d247d3384e0c03fdba` | 524,288 tuples | — | 0 | exhaustive WIDTH=8 |
| apb-interface-contract | `e30fd5242a1e84be92107d6be75652220748a8a7` | 2,697 checks | — | 0 | 0x28AB6407 |
| apb-modports-contract | `7fd99b382e13faa7a839610b63063a72748f4bf3` | 12,488 checks | — | 0 | 0x28AB4B05 |
| ahb16-contract | `659fba67ce85a01643cceca2c8d1e67ea3903995` | 924 checks | — | 0 | 0x28A81607 |
| cache-contract | `b6246eff1380aa0fb7812de9fccaf12b849fa1ca` | 1,639 checks | — | 0 | 0x28CACE17 |
| vga-raster | `8e257d11b1964fe82d4d4f3c3192b6a315d3b93d` | 29,588,940 comparisons | — | 0 | all256 |
| axi4-lite-standalone | `faf43379b24a524999eb2c8ad7e100cde35054c3` | 7 tests | 1 legal + 8 expected-negative PASS | 0 | directed |
| rv32i-soc | `dd574d8fa19810db110844d8f79b3862a7a93190` | 24 runs | 1 legal + 8 expected-negative PASS | 0 | 1, 17, 2026 |
| axi4-dma-full-ordering | `a2d3d57edaa9eb441f3289bf5320f4df2f074144` | 40 cases | — | 0 | 0x28A6BEEF |
| amba-reusable-verification | `c5f75cb35b95b3f43da4da44e65df3ec675fb17e` | 11 suites | — | 0 | deterministic |
| coherent-word-memory | `5f7837cc04f20689db64f1a2fc1264f86b6b44f2` | 71 cases | — | 0 | 0x28A6BEEF |

Functional counts have different units and are not combined into a coverage figure. The VGA suite also passed 7 original checks and 8 reset-edge temporal checks; the 29,588,940 count is the two-frame public-pin comparison count. The coherent suite also runs staged, concurrent, bridge, reset/commit, and shared-address core tests; its 71 count is the subsystem scenario count.

## Evidence and failure controls

[Raw main-run logs, JSON and generated summary](portfolio-merged-main/) include the per-suite commands, exit codes, durations, seeds and tool output. [Current capture manifest](CURRENT_CAPTURE_MANIFEST.json) distinguishes eight original CRLF simulator captures from the corresponding published LF Git VCDs. [Merged waveform audit](merged-waveform-byte-audit.json) compares all 30 VCDs across eleven clean `core.autocrlf=false` source clones with Git blobs and public raw downloads; 12 current figure metadata files were checked. Earlier reports remain unchanged. Newline conversion changes bytes and hashes, not simulation behavior.

[VGA release evidence](https://github.com/M-Roohan-Khan-28/VGA-SRAM-Framebuffer/tree/8e257d11b1964fe82d4d4f3c3192b6a315d3b93d/reports/technical-release-2026-11-08) records the old-oracle mismatch at 33 ns with wrapper exit 1, and the corrected clean-clone regression exit 0. [Checker propagation control](QUALIFICATION_CONTROL.md) records a disposable missing positive marker: seven functional AXI4-Lite tests passed, the checker qualification failed, and project and aggregate both exited 1. The mutation was local and was never pushed.

## Reproduce this exact lock

Choose unused short paths and put ModelSim Intel FPGA Starter Edition on `PATH`:

```powershell
$env:PATH = 'C:\intelFPGA\20.1\modelsim_ase\win32aloem;' + $env:PATH
git -c core.longpaths=true -c core.autocrlf=false clone --branch main https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\amba-release-reproduce-new
git -C C:\short\amba-release-reproduce-new config core.longpaths true
git -C C:\short\amba-release-reproduce-new config core.autocrlf false
git -C C:\short\amba-release-reproduce-new checkout --detach 9820035daf9a63f5bbf4fa14c2621a65a746cd85
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\short\amba-release-reproduce-new\scripts\run_portfolio_regression.ps1 -OutputDir C:\short\portfolio-release-reproduce-new
if ($LASTEXITCODE -ne 0) { throw 'A required suite failed or was blocked' }
Get-Content C:\short\portfolio-release-reproduce-new\results.json -Raw | ConvertFrom-Json | Select-Object aggregate_exit_code,runner_revision,inventory_revision,simulator_version
```

## Scope

This is bounded portable simulation evidence. The original advanced ALU/APB environments remain NOT RUN. UVM/SVA/coverage qualification, full inherited AXI/peripheral SoC, complete RV32I ISA, full protocol compliance, synthesis, timing, FPGA and hardware remain separate milestones.
