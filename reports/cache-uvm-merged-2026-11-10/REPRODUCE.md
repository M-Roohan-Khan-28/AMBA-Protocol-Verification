# Reproduce the merged-source cache UVM/SVA milestone

Use ordinary GitHub cloning and unused short paths. The tested environment is
the completed AMBA merge `b9c35a85113c99715ede572ab1f5dd94574b23e6`; it does not depend on a feature branch.
The DUT remains locked to `b6246eff1380aa0fb7812de9fccaf12b849fa1ca`. The runner and inventory last changed at
`9c74c35e0c2616a09af8824d2d85754738b5303a`. Keep the host awake during the serial run; do not change persistent
power settings. The recorded closeout used transient `SetThreadExecutionState`
with `ES_CONTINUOUS | ES_SYSTEM_REQUIRED`, restored in `finally`.

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\cache-merged-source-new
git -C C:\short\cache-merged-source-new config core.longpaths true
git -C C:\short\cache-merged-source-new config core.autocrlf false
git -C C:\short\cache-merged-source-new checkout --detach b9c35a85113c99715ede572ab1f5dd94574b23e6
& $python C:\short\cache-merged-source-new\scripts\run_cache_uvm.py --expected-env-sha b9c35a85113c99715ede572ab1f5dd94574b23e6 --output C:\short\cache-merged-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required cache milestone failed or was blocked' }
```

Qualified installations: Questa 2025.2 at
`C:/MXR/Quartus/25.1/questa_fse/win64`, vendor library
`C:/MXR/Quartus/25.1/questa_fse/uvm-1.2`, include directory
`C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src`.
The portable gate uses `C:/intelFPGA/20.1/modelsim_ase/win32aloem`.
The runner records exact commands, fingerprints and versions in `results.json`.
The UVM seed is `0x28A6BEEF` / 682016495; portable seed `0x28CACE17`.
Python and Git are required. No vendor source/library is redistributed.

The complete invocation must execute all 20 named entries serially, with
`milestone_pass=true`, aggregate exit 0 and actual process exit 0. Selection
mode is diagnostic and cannot qualify a full milestone. Bounds: 90 seconds
per simulator command, 600 seconds for the portable wrapper and 3,600 seconds
globally. The closeout's external wrapper used a 3,700-second bound. Missing
tools, markers, unexpected diagnostics, timeouts and failing suites fail closed.

The [actual tested command, output directory and outer exit](run/wrapper.json),
[raw wrapper log](run/wrapper.log), [normal-clone/detached receipts](source-receipts/fresh-clone.json)
and [results](run/results.json) record execution with fresh destinations.
Functional coverage, constrained randomization and original advanced ALU/APB
environments remain **NOT RUN**.
