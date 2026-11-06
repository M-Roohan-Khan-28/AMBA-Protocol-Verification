# Results

The committed local source `460dfba6d477bb3427adcfdbea1d39c5f3fd5d09`
was tested with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_amba.ps1 -OutputDir C:\R_MIGRATION_BACKUP\Roohan_GitHub_Launch_Kit\Roohan_GitHub_Launch_Kit\build\test-runs\amba-committed-v2-2026-11-06
```

ModelSim Intel FPGA Starter Edition
`vsim 2020.1 Simulator 2020.02 Feb 28 2020` ran a clean worktree.
All **nine required suites passed**; aggregate exit **0**. Each simulator
process exited 0 and its log had zero simulator errors and warnings. Exact
DUT commits, elapsed times and log paths are in
`reports/committed-2026-11-06/results.json`.

| Suite | Recorded result |
| --- | ---: |
| APB real DUT | 256 transfers, 452 checks, 0 monitor violations |
| APB missing-setup negative | 1 violation detected |
| APB configurable responder | 7 transfers, 13 checks, 14 wait edges |
| AHB-Lite real DUT | 67 accepted addresses, 119 checks, 0 monitor violations |
| AHB-Lite stalled-control negative | 2 violations detected |
| AXI4-Lite real DUT | 26 writes, 34 reads, 98 checks, 0 monitor violations |
| AXI4-Lite stalled-AW negative | 2 violations detected |
| AXI4 DMA plus passive monitor | 25 DMA cases, 824,446 byte/model comparisons; post-reset monitor observed 21 read and 21 write bursts, 315 accepted beats each |
| AXI4 4 KiB-crossing negative | 1 violation detected |

The negative tests require their injected violation to be detected; they do
not count a protocol violation as a positive DUT result. An additional
disposable commit `5e8511a0711137cc4265c04137d9ea070890dc80` inverted
the APB oracle comparison. Its simulation logged
`Fatal: APB read index=0 got=00000000 expected=00000000` and one simulator
error. The AMBA runner marked the suite `FAIL` and returned aggregate exit
**1**, even though that ModelSim invocation returned process exit 0. The
clean source was never changed by this fault.

The copied portfolio runner was also executed before this milestone:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_portfolio_regression.ps1 -OutputDir C:\R_MIGRATION_BACKUP\Roohan_GitHub_Launch_Kit\Roohan_GitHub_Launch_Kit\build\test-runs\portfolio-amba-milestone-2026-11-06
```

All nine existing mandatory project suites passed, aggregate exit **0**.
That run does not count the AMBA suites a second time. The original
licence-dependent ALU/APB advanced environments remain `NOT RUN`.

The published source was cloned from
`https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git` at
`afd551d1df46cb265661852e9e743c3c56f96ce7`, then run with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_amba.ps1 -OutputDir C:\R_MIGRATION_BACKUP\Roohan_GitHub_Launch_Kit\Roohan_GitHub_Launch_Kit\build\test-runs\amba-published-clone-2026-11-06
```

All nine suites passed again, aggregate and wrapper exit **0**, at the
same pinned DUT revisions and with the same observed counts above. Raw
compile/simulation logs and JSON are in
`reports/published-clone-2026-11-06/`. This evidence-only documentation
change does not modify the tested checker, driver, or adapter source.

No functional coverage percentage, complete AMBA protocol compliance, UVM,
synthesis, timing, FPGA, or hardware result is claimed.

## Corrective response-order run — 7 November 2026

Clean source `e2f72f4391aa750d761e99ef8c3009e8af2c47e1` ran
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_amba.ps1 -OutputDir build/corrective-amba-committed-v2-2026-11-07` with ModelSim Intel FPGA Starter Edition `vsim 2020.1 Simulator 2020.02 Feb 28 2020`. All **11 internal simulations passed**, each simulator exit 0, aggregate and wrapper exit **0**; their compile and simulation logs reported zero errors and warnings. Raw logs and [JSON](../reports/corrective-2026-11-07/amba-committed/results.json) are retained separately from historical evidence.

The unchanged APB, responder, AHB-Lite, and AXI4-Lite adapter checks remained 452, 13, 119, and 98. The existing AW instability and page-crossing detectors still reported 2 and 1 detected violations. Two new negative simulations each exercised four response-order scenarios: early BVALID held with BREADY low, early RVALID held with RREADY low, and same-edge B and R dependencies. Each reported `scenarios=4`; the checks use transaction state from before the edge. The corrected DMA adapter at pinned commit `be66a550fd74f0f85d73940f5ade15f1691b083b` passed **27 cases and 925,460 checks**, including legal W-before-AW acceptance; the passive bounded monitor found zero violations. Its final-segment marker is 21 read and 21 write bursts, 315 beats each because the DMA bench resets the monitor between cases. That marker is not a total across 27 cases. The two earlier AXI negative suites remain distinct from the two new response-order suites.

These are bounded monitor and reference-model checks. They do not establish full AXI or AMBA compliance or measured coverage.
