# Reproduce the merged deterministic DMA milestone

Use unused short paths. A normal clone followed by an explicit detached checkout
selects the actual merged environment; no feature branch is required.

```powershell
git -c core.longpaths=true -c core.autocrlf=false clone https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\dma-merged-source-new
git -C C:\short\dma-merged-source-new checkout --detach 54833a559d7afbc741c08f41f7df6b3dd24a2b52
& C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe C:\short\dma-merged-source-new\scripts\run_dma_uvm.py --expected-env-sha 54833a559d7afbc741c08f41f7df6b3dd24a2b52 --output C:\short\dma-merged-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required DMA UVM/SVA regression failed or was blocked' }
```

The single runner command executes all 47 required substeps serially, including
all ten expected-failure child wrappers. Defaults use the qualified Questa
`C:/MXR/Quartus/25.1/questa_fse/win64`, matching `uvm-1.2` library and
`verilog_src/uvm-1.2/src` include directory. `--sim-bin`, `--uvm-lib` and
`--uvm-include` may select the same qualified configuration at another location.
The deterministic seed is `0x28A6BEEF` / `682016495`.

[The actual invocation and wrapper exit](run/wrapper.json),
[all simulator commands, input hashes and results](run/results.json), and
[normal-clone/detached receipts](source-receipts/fresh-clone.json) record this run.
The parent fetched the locked DUT from GitHub without a mirror override. Fault
children used isolated local clones of that verified source, with explicit
receipts and disposable mutations; the pinned checkout stayed pristine.
Missing tools, source mismatches, missing markers, unexpected errors and timeouts
produce nonzero results. A targeted selection cannot claim a complete milestone.

The preserved [old/new controls](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/blob/08bde7496be07c83c3acd546ecef6bc7e6cc40b5/reports/dma-uvm-corrective-2026-11-10/SUMMARY.md) have their own commands and results;
they were not rerun as historical campaigns in this merged-source closeout.
