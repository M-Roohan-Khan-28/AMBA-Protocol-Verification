# Locked portfolio regression — 7 November 2026

## Current technical completion run

The newer [technical completion report](TECHNICAL_COMPLETION.md) records the full-SHA locked eleven-project run from fresh GitHub clones at runner commit 35239784a519f163cb71104e088c952e3d4a69fc. It passed 11/11 required suites with aggregate exit 0 and keeps the two original advanced ALU/APB environments NOT RUN. The historical corrective regression and its original locks remain documented below.

## Earlier corrective regression

The runner and inventory at commit `0f126b0503dd1688bc805cc00e0c847cded95988`
were cloned fresh from the public corrective branch. The runner made a fresh
GitHub clone for each enabled suite, checked out the inventory's full 40-digit
SHA in detached mode, and compared the observed HEAD against the lock. The
machine-readable [results](../reports/corrective-2026-11-07/portfolio-locked/results.json)
record the runner, runner-script and inventory commit revisions, SHA-256 file
hashes, all expected/observed source revisions, commands, simulator version,
seeds, exits, elapsed times and log paths. The runner worktree was clean.

From a fresh clone, explicitly select the published runner commit
`9afad00dd5dfbe89fa498b54e613c2563fcd5803`. GitHub network access and
ModelSim Intel FPGA Starter Edition 2020.1 are needed; choose a new output
directory:

```powershell
git -c core.longpaths=true clone https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git AMBA-portfolio-reproduction
Set-Location AMBA-portfolio-reproduction
git config core.longpaths true
git checkout --detach 9afad00dd5dfbe89fa498b54e613c2563fcd5803
git rev-parse HEAD
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_portfolio_regression.ps1 -OutputDir build/portfolio-reproduction-1
if ($LASTEXITCODE -ne 0) { throw 'Required portfolio suite failed or was blocked' }
```

The recorded clean-clone run used
`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_portfolio_regression.ps1 -OutputDir C:\R_MIGRATION_BACKUP\Roohan_GitHub_Launch_Kit\Roohan_GitHub_Launch_Kit\build\test-runs\portfolio-corrective-remote-clones-2026-11-07`.
Its ModelSim version was `vsim 2020.1 Simulator 2020.02 Feb 28 2020`.
**All 11 required project suites passed; every required wrapper exit was 0;
aggregate exit was 0.** The two original advanced ALU/APB suites remained
explicitly `NOT RUN` because the `svverification` licence is unavailable.

| Required project suite | Actual result |
| --- | ---: |
| ALU portable | 1,380 checks |
| APB interface portable | 1,317 checks |
| APB modports | 2 checks |
| AHB-Lite RAM | 18 checks |
| Two-way cache | 7 checks |
| VGA SRAM | 7 checks |
| Standalone AXI4-Lite | 7 tests |
| RV32I AXI4-Lite SoC | 24 runs |
| Corrected AXI4 DMA | 27 cases, 925,460 internal checks |
| Corrected AMBA verification | 11 internal simulations |
| Corrected coherent memory | 71 subsystem scenarios, plus 135 staged and 106 concurrent core checks |

Counts measure different things and are not combined coverage. The DMA uses
seed `0x28A6BEEF`; the coherent subsystem uses the same seed for its seeded
contention scenarios; the RV32I SoC varying-latency runs use seeds 1, 17 and
2026. The other suites are directed or deterministic as recorded per suite.
The AMBA project entry runs `scripts/run_amba.ps1`; it never calls this
portfolio runner recursively. [Raw suite logs, JSON, runner console and
summary](../reports/corrective-2026-11-07/portfolio-locked/) are published
separately from earlier reports.

The runner requires a clean source tree, a full SHA lock for each inventory
entry, a successful detached checkout and exact revision match. It treats
missing Git/ModelSim tools, source clones, result markers, simulation logs,
`$finish`, zero-error summaries and expected counts as blocked or failed;
simulator errors/fatals and timeouts likewise prevent PASS. Any required
suite that is failed, blocked or unexecuted makes the aggregate exit nonzero.
Disposable one-suite self-checks of this runner returned exit **1** for a
missing ModelSim path (`BLOCKED`), a missing result marker (`FAIL`), a
one-second timeout (`FAIL`), a mandatory disabled suite (`NOT RUN`) and an
injected DMA source-alias fatal (`FAIL`). The injected source commit
`422469606a2efd68983aca35354eac52368aa6fa` was local only and was
never pushed. [Self-check inventories, logs and JSON](../reports/corrective-2026-11-07/selfchecks/)
show each result. Historical reports remain unchanged.

This regression does not establish equivalent coverage for the original
licence-dependent environments, complete AMBA or AXI compliance, the
inherited full coherent AXI/peripheral SoC, complete RV32I ISA behavior,
coverage closure, synthesis, timing, FPGA or hardware operation.

## Post-merge Windows checkout correction

After the first merge at `e08192562cb66d01585c9a1e26d8090cb5871a78`,
a fresh-main aggregate returned **exit 1**: ten required suites passed, but
the AMBA entry was `BLOCKED` when checkout of its locked ancestor hit a
Windows filename-length error in the newly published evidence paths. The
runner did not mark that run as passed. Its [JSON, summary and console](../reports/longpath-2026-11-07/failed/)
are retained.

Follow-up runner code `58d0a16ac49aa8827b364cf525c3dca7d7f47a08`
persists `core.longpaths=true` inside each fresh source clone before the
detached locked checkout. A targeted AMBA entry then completed its **11
internal simulations**, wrapper and one-entry aggregate exit **0**. The
complete rerun from that clean runner worktree used the same command above
with a fresh output directory
`C:\R_MIGRATION_BACKUP\Roohan_GitHub_Launch_Kit\Roohan_GitHub_Launch_Kit\build\test-runs\portfolio-corrective-longpath-fixed-2026-11-07`.
ModelSim Intel FPGA Starter Edition reported
`vsim 2020.1 Simulator 2020.02 Feb 28 2020`; **all 11 required project
suites passed**, every required suite exit 0, aggregate exit **0**. The two
advanced licence-dependent suites remained `NOT RUN`. The JSON records
runner and runner-script revision `58d0a16...`, inventory revision
`0f126b0...`, the exact file SHA-256 values, a clean runner, and every
matching source lock. [Targeted and full passing raw logs, JSON, summary
and console](../reports/longpath-2026-11-07/) are retained alongside the
failed run. The fix changes checkout configuration only; the tested project
source locks and expected counts remain unchanged.

## Verification backlog (nonblocking)

Split the AXI4 same-edge B and R response-order negative cases into separate,
reset-isolated scenarios with an individual expected detection for each.
The published four-scenario negative tests passed as recorded above; this
follow-up would make each same-edge failure easier to attribute. It is not
counted as an additional executed suite or coverage result.
