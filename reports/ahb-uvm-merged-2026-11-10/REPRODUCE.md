# Reproduce the merged AHB UVM/SVA milestone

Use unused short paths. A normal GitHub clone followed by an explicit detached
checkout selects the tested merged source. No feature branch is required.

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\ahb-merged-source-new
git -C C:\short\ahb-merged-source-new checkout --detach e58c30428d2a6348d3983c8ee3fbf9e1905629d2
& $python C:\short\ahb-merged-source-new\scripts\run_ahb_uvm.py --expected-env-sha e58c30428d2a6348d3983c8ee3fbf9e1905629d2 --output C:\short\ahb-merged-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required AHB milestone failed or was blocked' }
```

This one runner command executes the full named 44-substep inventory serially.
The default qualified Questa configuration is
`C:/MXR/Quartus/25.1/questa_fse/win64`, with the matching bundled `uvm-1.2`
library and `verilog_src/uvm-1.2/src` include path. The portable substep uses
`C:/intelFPGA/20.1/modelsim_ase/win32aloem`. Other installations must be separately
qualified; `--sim-bin`, `--uvm-lib` and `--uvm-include` can select their locations.
Seed: `0x28A6BEEF` / `682016495`; separate portable seed `0x28A81607`.

[Actual executed argv, path, elapsed time and outer exit](run/wrapper.json),
[all commands/tool exits and source locks](run/results.json), and
[fresh-clone receipts](source-receipts/fresh-clone-v2.json) record this run.
Actual output: `C:/short/ahb-merged-run-v2-20261110`; it was fresh before execution.
The parent cloned the DUT from GitHub at `659fba67ce85a01643cceca2c8d1e67ea3903995`. Fault children used
isolated local clones of that verified source; the locked checkout stayed clean.
Missing tools, timeouts, source mismatches, absent expected markers and unexpected
errors produce nonzero results. A `--select` run cannot claim the full milestone.
