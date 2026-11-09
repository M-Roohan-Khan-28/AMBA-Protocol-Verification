# Reproduce the separate deterministic DMA milestone

The clean-clone run used the exact environment revision below, a new output
directory, and the runner's default qualified Questa/UVM paths. Choose unused
short paths. The runner clones the DUT separately and verifies its full SHA.
Use an installed Python 3 interpreter; the explicit Python path below is the
tested host's interpreter. `--sim-bin`, `--uvm-lib` and `--uvm-include` can select
an equivalent separately qualified installation. Simulator sessions are serial.

```powershell
git -c core.longpaths=true -c core.autocrlf=false clone --branch advanced/dma-deterministic-uvm https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\dma-uvm-reproduce-new
git -C C:\short\dma-uvm-reproduce-new checkout --detach e93a6fdff85804dab7b5e636e43880e1ba7615ab
& C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe C:\short\dma-uvm-reproduce-new\scripts\run_dma_uvm.py --expected-env-sha e93a6fdff85804dab7b5e636e43880e1ba7615ab --output C:\short\dma-uvm-results-new
if ($LASTEXITCODE -ne 0) { throw 'DMA UVM milestone failed or was blocked' }
```

The exact executed command, actual wrapper exit and console hash are in
[run/wrapper.json](run/wrapper.json); all compiler/simulator commands, tool/input
hashes and source locks are in [run/results.json](run/results.json).
This command executes only this milestone. It does not replace the preserved
eleven-project, APB or AXI4-Lite release reproduction commands.
