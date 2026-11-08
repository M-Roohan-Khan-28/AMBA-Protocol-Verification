# Separate APB advanced-verification milestone

This milestone adds a reusable UVM 1.2 environment; it does not replace the
completed eleven-project portable release or its locked evidence. The DUT
sources, original advanced benches, licences and attribution remain in their
original repositories. The two adapters use the full SHA locks in
[`sources.json`](../verification/apb_uvm/sources.json), with fresh detached
source clones and expected/observed revision checks.

[Actual execution evidence and limitations](../reports/advanced-apb-2026-11-08/SUMMARY.md)
are recorded separately from the source implementation.

## Architecture and supported contracts

`apb_item` / sequencer -> driver -> generic `apb_bus` -> native DUT adapter.
The passive monitor samples the public pins through a `#1step` input clocking
block and publishes accepted transfers and resets to an independent scoreboard
and requirements subscriber. The driver changes controls at falling edges.
The scoreboard uses arithmetic address decoding, a separate memory array and
contract-derived errors. It never reads DUT memory or driver expected results.
Assertions sample pre-edge values. Reset aborts occur between clock edges.

| Adapter | Target | Address/data/reset contract |
| --- | --- | --- |
| 0 | APB-Interface-Verification | 64 x 32-bit words, byte address low bits alias, PREADY always high, no errors, asynchronous reset clears RAM |
| 1 | APB-Modports-Verification | Four aligned words at 0,4,8,12; other addresses error with no write side effect; zero wait; asynchronous reset clears RAM |
| 2 | Existing synthetic APB responder | Three usable words, reserved word 3 and out-of-range errors, two wait cycles; qualification target, not a third published DUT |

Each simulation compiles only one native interface definition. The generic
interface does not alter either DUT. Data widths, address widths and response
rules are these educational implementations, not a universal APB implementation.
Architecture follows the monitor/analysis/scoreboard pattern in the
[Accellera UVM 1.2 User's Guide](https://www.accellera.org/images/downloads/standards/uvm/uvm_users_guide_1.2.pdf).
No vendor UVM library or headers are redistributed.

## Requirements and coverage model

| ID | Stimulus and independent check | Measurement |
| --- | --- | --- |
| R1 | Read every word after initial and later reset; write/read every usable word | Scoreboard comparisons; per-word read/write hit requirements; `traffic_cg` direction x word |
| R2 | Zero, all ones, alternating and address-dependent mixed data | Independent memory model; four data-class requirements / coverpoint |
| R3 | All 256 byte addresses, both write and read, then reread valid memory | Error expectations, alias semantics, invalid-write side effects; alias bins only for adapter 0; error direction x cause only for adapters 1/2 |
| R4 | Back-to-back transfers; setup and access stability; enable requires select | Five concurrent assertions and exact submission/acceptance/completion counts |
| R5 | Two-cycle waits and held controls | Synthetic target only, `wait_cg` two-cycle bin; wait stability assertion |
| R6 | Asynchronous reset during setup, and during a pending wait on adapter 2 | Abort count, reset event coverage, readback of cleared memory, no extra accepted transfer |
| R7 | Malformed setup, wait hold, access entry, enable/select and early error | Five separate reset-isolated assertion controls, exactly one named detection each; one legal control must have zero |
| R8 | Corrupt accepted read data through a deliberate verification adapter control | `+FAULT_READ`; independent scoreboard fatal and nonzero runner result |

`--mode deterministic` executes UVM, concurrent assertions and procedural
requirement checks. It does not call `randomize()` or instantiate a covergroup.
Its `requirements.json` is explicitly a procedural hit report, **not simulator
functional coverage**. It is useful executable evidence on the installed licence.

`--mode coverage` explicitly compiles `APB_ENABLE_COVERGROUP` and requires
successful simulation, a UCDB and an exported `vcover report -details -cvg`
report. The per-contract groups avoid demanding error or wait bins from targets
that cannot implement them. Coverage collection, bin review and closure remain
NOT RUN until this mode can execute with a suitable licence. Reset-phase and
back-to-back functional coverpoints beyond the procedural checks are still a
coverage-model extension; this model is not full APB coverage closure.

## Commands

Python 3.9+, Git, Questa and the matching installed precompiled UVM 1.2 library
are required. Use fresh output directories. No script installs software or
changes licence configuration. Example for the installation used here:

```powershell
python scripts/run_apb_uvm.py --sim-bin C:\MXR\Quartus\25.1\questa_fse\win64 --uvm-lib C:\MXR\Quartus\25.1\questa_fse\uvm-1.2 --uvm-include C:\MXR\Quartus\25.1\questa_fse\verilog_src\uvm-1.2\src --output C:\short\apb-uvm-new
if ($LASTEXITCODE -ne 0) { throw 'Required APB UVM/SVA substep failed or was blocked' }
# Requires covergroup licence; nonzero is expected while blocked:
python scripts/run_apb_uvm.py --sim-bin C:\MXR\Quartus\25.1\questa_fse\win64 --uvm-lib C:\MXR\Quartus\25.1\questa_fse\uvm-1.2 --uvm-include C:\MXR\Quartus\25.1\questa_fse\verilog_src\uvm-1.2\src --mode coverage --output C:\short\apb-coverage-new
```

Use `--inject-read-fault` with a new output directory for a nonzero fault control;
it is never a positive regression. Individual adapters can be selected with
`--adapters 0`, `1` or `2`. All six assertion qualification simulations remain
required. Missing tools, markers, output reports, timeouts and simulator/UVM
fatals cause nonzero exits even when the simulator process itself exits zero.

## Capability probes

The probes under `verification/capabilities/probes/` originate from the owner's
Roohan Technical Completion Pack. `probe_modelsim.py` is its bounded runner,
extended here with a self-contained source path and required functional coverage
export. The SVA probe emits an explicit expected-failure detection and requires
exactly one assertion action. Original pack files and earlier reports are intact.

```powershell
python verification/capabilities/probe_modelsim.py --sim-bin C:\MXR\Quartus\25.1\questa_fse\win64 --uvm-lib C:\MXR\Quartus\25.1\questa_fse\uvm-1.2 --uvm-include C:\MXR\Quartus\25.1\questa_fse\verilog_src\uvm-1.2\src --output C:\short\apb-capabilities-new
```

All requested probes must pass for this wrapper to exit zero. Library import
or compile success alone does not qualify UVM, assertions, randomization or
coverage. The original advanced ALU/APB environments retain their features;
they must remain NOT RUN while their randomization/covergroup licence is blocked.

## Evidence byte policy and scope

New evidence is added in a new report directory. New VCDs are stored byte-for-byte
with `-text` attributes; capture, Git blob, raw-download and checkout hashes must
agree. Figures are rendered from those exact VCD bytes by `tools/vcd_to_svg.py`.
Their captions identify actual UVM simulation traces; assertion-control traces
are injected violations. No waveform by itself establishes correctness.

This milestone does not establish complete APB compliance, randomized closure,
full portfolio UVM verification, complete RV32I ISA, synthesis, timing, FPGA or
hardware operation. The original portable release remains separately reproducible.
