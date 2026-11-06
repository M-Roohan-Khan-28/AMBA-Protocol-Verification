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
