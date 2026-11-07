# Required AXI4-Lite checker propagation control

Clean detached aggregate runner and script revision:
`d6a0c6129eee66e05cc19f67a6341e4ed6acec24`.
ModelSim Intel FPGA Starter Edition:
`vsim 2020.1 Simulator 2020.02 Feb 28 2020`.
All cases were directed; no random seed was used.

| One-suite control | Functional tests | Checker qualification | Project exit | Aggregate exit |
| --- | ---: | --- | ---: | ---: |
| Published AXI4-Lite main `faf43379b24a524999eb2c8ad7e100cde35054c3` | 7 passed | 1 legal and 8 expected-negative passed | 0 | 0 |
| Disposable local source `80c2cc1e8466330ef5dd5e093a4486408a988616` | 7 passed | case 0 marker deliberately changed to an impossible `writes=999`; checker `FAIL` | 1 | 1 |

The fault was a one-line change in the local checker qualification script;
it was never pushed. The fault run's source SHA matched its disposable lock,
and the runner worktree was clean. `fault/output/checker-response-order/RESULTS.json`
reports `Unexpected result in case 0`. The wrapper and aggregate did not
mark the suite PASS. Both control inventories, the mutant checker script,
raw functional and checker logs, wrapper consoles, JSON, and summaries are in
`qualification-control/`. An initial preparation attempt used a detached
local source repository and stopped at clone/checkout; it was not counted as
qualification evidence. The branch-backed source rerun above reached the
intended fault.

Reproduce the positive one-suite control with fresh paths:

```powershell
git -c core.autocrlf=false clone --branch technical/response-order-qualification https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\amba-control-new
git -C C:\short\amba-control-new config core.autocrlf false
git -C C:\short\amba-control-new checkout --detach d6a0c6129eee66e05cc19f67a6341e4ed6acec24
$one = @(Get-Content C:\short\amba-control-new\scripts\portfolio_suites.json -Raw | ConvertFrom-Json | Where-Object name -eq 'axi4-lite-standalone')
$one[0].revision = 'faf43379b24a524999eb2c8ad7e100cde35054c3'
$one | ConvertTo-Json -Depth 10 | Set-Content C:\short\axil-control-inventory-new.json
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\short\amba-control-new\scripts\run_portfolio_regression.ps1 -InventoryPath C:\short\axil-control-inventory-new.json -OutputDir C:\short\portfolio-control-new
if ($LASTEXITCODE -ne 0) { throw 'Qualification control failed or blocked' }
```
