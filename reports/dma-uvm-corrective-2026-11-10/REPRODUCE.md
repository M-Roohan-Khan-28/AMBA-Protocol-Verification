# Reproduce the corrected deterministic DMA milestone

Use unused short directories. Clone normally (no feature branch dependency),
then explicitly detach at the complete tested environment revision.

```powershell
git -c core.longpaths=true -c core.autocrlf=false clone https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\dma-corrective-source-new
git -C C:\short\dma-corrective-source-new checkout --detach e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d
& C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe C:\short\dma-corrective-source-new\scripts\run_dma_uvm.py --expected-env-sha e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d --output C:\short\dma-corrective-results-new
if ($LASTEXITCODE -ne 0) { throw 'DMA UVM corrective regression failed or was blocked' }
```

This one Python command derives its required inventory from the locked JSON and
runs all 47 substeps serially, including fault-child wrappers. The default
qualified paths are `C:/MXR/Quartus/25.1/questa_fse/win64`, the matching
`uvm-1.2` library and `verilog_src/uvm-1.2/src` includes. Override with
`--sim-bin`, `--uvm-lib`, `--uvm-include` if installed elsewhere. Required tools,
clean source/lock validation, markers and bounded commands fail closed.
Actual executed commands and exits are in [run/wrapper.json](run/wrapper.json),
[run/results.json](run/results.json) and [fresh clone receipts](source-receipts/fresh-clone.json).
The published run cloned both environment and DUT from GitHub, detached at full
SHA locks. No `--dut-mirror` was used for this final run.

Targeted selection is diagnostic and cannot set `milestone_pass=true`:
`--select inactive-lanes`, `--select csr-readbacks fault-csr_idle_side_effect fault-csr_busy_side_effect`,
or `--select fault-active_data fault-tail_strobe`. Always use a new output directory.

## Reproduce the historical test comparison

The old inactive-lane run uses public intermediate commit
`c43c631e44452aee0a9447efd3b44b660e8c7119`: its scoreboard is byte-identical
to reviewed `e93a6fdff85804dab7b5e636e43880e1ba7615ab`, with the new legal
adapter/control inventory. Select `inactive-tail-1` through `inactive-tail-7`.
Each is a legal DUT case that the old full-word data oracle falsely rejects.

For the old CSR comparison, start a separate disposable checkout of `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d`,
apply [the exact old-test patch](old-tests/restore-reviewed-tests.patch), and commit
that local test-only variant before running the strict wrapper with its new
`--expected-env-sha`. The patch restores only the reviewed driver, scoreboard
and accounting validator; [source identities](source-receipts/old-csr-source.json)
and exact restored files in `old-tests/` are supplied. Select
`fault-csr_idle_side_effect fault-csr_busy_side_effect --raw-fault`.
This reproduces the old tests' missing detection, not a valid DUT pass.
The corrected run's ordinary fault parents require child exit 1 and the precise
`CSR_READ` register mismatch. Every mutation is generated outside the pristine
DUT checkout, with original/compiled hashes and an exact diff in `disposable-rtl/`.
The DUT lock never changes.
