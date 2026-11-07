# AXI4 response-order negative qualification

The bounded AXI4 monitor checks BVALID/RVALID eligibility from pre-edge
accepted transactions, including cycles with BREADY/RREADY low. The updated
`axi4_response_negative` bench isolates four cases with resets: held early B
(3 expected detections), held early R (3), same-edge AW/W/B (1), and same-edge
AR/R (1). Each scenario checks its own violation count before printing its
marker. The four-scenario aggregate marker remains unchanged.

This work was prepared against AMBA main
`c5ab4768d30f58b7a006ee329617be29f099eb99`; the focused test and
fault-control script were committed at
`4fd419cadb62713e91580739d2978cb551513157`. The production monitor
source was not changed. The [full AMBA internal run](../reports/technical-completion-2026-11-07/internal-11-simulations/results.json)
passed 11/11 simulations, aggregate exit 0, on that clean source revision.
Its four pinned DUT source revisions are recorded in the JSON and
`scripts/run_amba.ps1`.

The [fault controls](../reports/technical-completion-2026-11-07/response-fault-controls/results.json)
also passed under ModelSim Intel FPGA Starter Edition `vsim 2020.1 Simulator
2020.02 Feb 28 2020`. The original monitor accepted all four expected cases.
In separate disposable copies, masking the same-edge B rule let both held
cases pass and made the same-edge B case fail with its exact missing-detection
fatal. Masking only the same-edge R rule let the first three cases pass and
made the same-edge R case fail. The script requires the exact prior markers,
one expected fatal, absence of the aggregate PASS marker, and a 90-second
wall-clock bound. ModelSim Starter returned process status 0 even on those
intentional `$fatal`s; the transcript recorded `Errors: 1`. This is why the
script checks diagnostics as well as process status.

Reproduce with new output directories:

```powershell
$env:MODELSIM_BIN = 'C:\intelFPGA\20.1\modelsim_ase\win32aloem'
py -3 scripts/qualify_axi4_response_negative.py --output-dir C:\short\amba-fault-controls-unique
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_amba.ps1 -OutputDir C:\short\amba-internal-unique
```

The [measured waveform](../reports/technical-completion-2026-11-07/response-fault-controls/original/measured.svg)
was rendered from the simulator's [selected-signal VCD](../reports/technical-completion-2026-11-07/response-fault-controls/original/measured.vcd).
The [capture log](../reports/technical-completion-2026-11-07/response-fault-controls/original/measured.log)
and [renderer metadata](../reports/technical-completion-2026-11-07/response-fault-controls/original/measured.json)
record the actual source hash and 1 ps VCD timebase. The figure shows the
intentionally illegal stimulus and observed violation counter; it is not a
legal protocol example or a coverage measure. `tools/vcd_to_svg.py` renders
samples without grading the monitor.

The two original advanced ALU/APB environments remain licence-blocked and
NOT RUN. This bounded AMBA suite does not establish complete AXI/APB/AHB
compliance, functional/code coverage closure, synthesis, timing, FPGA, or
hardware behavior. Historical reports and attribution remain unchanged.
