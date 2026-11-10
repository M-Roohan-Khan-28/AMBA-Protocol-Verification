# Reproduce deterministic VGA UVM/SVA

Use unused short paths, ordinary GitHub cloning and explicit detached checkout.
This does not require selecting a feature branch. The full invocation executes
all 37 named required entries serially, including measured evidence.
Keep the host awake for the long raster runs. The tested outer wrapper used a
transient SetThreadExecutionState request, restored afterward; no persistent
power settings changed.

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\vga-uvm-source-new
git -C C:\short\vga-uvm-source-new checkout --detach 3afa2912076b6e7dadf6c958d444e2dc9a2a87f4
& $python C:\short\vga-uvm-source-new\scripts\run_vga_uvm.py --expected-env-sha 3afa2912076b6e7dadf6c958d444e2dc9a2a87f4 --output C:\short\vga-uvm-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required VGA milestone failed or was blocked' }
```

Qualified Questa executable directory:
`C:/MXR/Quartus/25.1/questa_fse/win64`; UVM library:
`C:/MXR/Quartus/25.1/questa_fse/uvm-1.2`; UVM includes:
`C:/MXR/Quartus/25.1/questa_fse/verilog_src/uvm-1.2/src`.
The existing portable gate uses ModelSim at
`C:/intelFPGA/20.1/modelsim_ase/win32aloem` and calls the locked
`scripts/run_regression.ps1`, without substituting a historical launcher.
Python 3.9+ and Git are required; vendor libraries are not redistributed.

Actual environment `3afa2912076b6e7dadf6c958d444e2dc9a2a87f4`; runner last-change `20c9eaa4d79209fb46323451be0783f1d8fe6df2`;
inventory last-change `20c9eaa4d79209fb46323451be0783f1d8fe6df2`; DUT `8e257d11b1964fe82d4d4f3c3192b6a315d3b93d`.
The UVM simulator seed is `0x28A6BEEF` / 682016495. Stimulus is deterministic;
this does not execute constrained randomization. Input period is 10 ns in
simulation. No board clock, physical pixel frequency or refresh rate is claimed.

Bounds are 180 seconds per ordinary command, 900 seconds per real-DUT raster
simulation, 600 seconds for the portable wrapper and 5,400 seconds globally.
The functional workload was measured against that unchanged 900-second bound.
The external wrapper has a 5,500-second limit. Missing tools/licences, required
markers or evidence, timeouts, dirty/mismatched source and unexpected fatals
must return nonzero. Diagnostic `--select` runs never set milestone_pass=true.

[Actual wrapper command/exit](wrapper.json), [raw console](wrapper.log),
[complete results](run/results.json) and [source/input hashes](SOURCE_LOCKS.json)
are retained. Check `milestone_pass=true`, aggregate_exit_code=0 and the actual
process exit 0; check every required name, not only the total.
