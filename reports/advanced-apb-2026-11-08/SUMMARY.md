# Separate APB advanced-verification milestone — 8 November 2026

**Deterministic UVM/SVA: PASS. Full advanced-feature milestone: INCOMPLETE.**
Functional covergroup execution/export and constrained randomization remain
licence-blocked. The original advanced ALU/APB environments are **NOT RUN**.
The completed eleven-project portable release, its source locks and historical
evidence are unchanged. These results are a separate branch milestone.

## Tested revisions and results

The local clean source was `eab4791cf7260ba95aa1ca4e250acfa29a11702f`.
A fresh GitHub clone, detached at published source
`ff158f4f7ed844f2a7ab9b3e19423ebc50be8f60`, reproduced all nine required
substeps with **wrapper exit 0**. Both runs recorded clean source trees.
The latter commit changes only waveform crop selection/provenance; all
simulator inputs match the local tested revision ([comparison](SOURCE_EQUIVALENCE.json)).

| Required UVM target | Pinned DUT source | Accepted transfers | Independent comparisons | Observed resets / aborted requests | Result |
| --- | --- | ---: | ---: | ---: | --- |
| 64-word APB interface RAM | `e30fd5242a1e84be92107d6be75652220748a8a7` | 1,280 | 2,048 | 3 / 1 | PASS |
| Four-word APB modport RAM | `7fd99b382e13faa7a839610b63063a72748f4bf3` | 560 | 848 | 3 / 1 | PASS |
| Synthetic two-wait responder | Existing AMBA responder, same source tree | 554 | 840 | 4 / 2 | PASS |

These are separate units, not coverage percentages. Submitted, observed accepted
and driver-completed transaction counts matched exactly. Every positive run had
zero UVM errors/fatals and zero APB assertion detections. The three compiles had
zero errors/warnings; each simulation reported zero errors and one counted warning,
`vopt-10908` from `+acc`, plus a separate `onerror` warning about use outside a macro. Full logs are retained without filtering.

Five additional reset-isolated simulations each detected exactly one intended
assertion violation: `SETUP`, `WAIT_HOLD`, `ACCESS_ENTRY`, `ENABLE_SELECT`, and
`ERROR_ELIGIBILITY`. A sixth legal wait-state control had zero detections.
These six controls are required by the same runner, separately from functional
transaction counts. [Clean-clone JSON and command records](clean-positive/results.json)
and [local positive JSON](local-positive/results.json) contain all exits, source
checks, input hashes, requirement counters and raw log paths.

Tool: **Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025**.
UVM library: installed precompiled `uvm-1.2`, matching installed UVM 1.2 headers;
runtime reports `QUESTA_UVM-1.2.3`. No vendor library/header is redistributed.
Simulator seed: `682016495` (`0x28A6BEEF`); deterministic sequences do not call
`randomize()`. Mixed write values are deterministic address-dependent arithmetic.

## Feature qualification and genuine blockers

| Capability | ModelSim Intel FPGA Starter 2020.1 | Questa Altera Starter 2025.2 |
| --- | --- | --- |
| Basic SV / interfaces | Executed PASS | Executed PASS |
| UVM | NOT RUN: matching library not configured for this installation | UVM 1.2 smoke and new deterministic environment executed PASS |
| Constrained randomization | Licence-blocked | Licence-blocked (`svverification`) |
| Concurrent SVA | Execution proof failed; expected action did not run | PASS: deliberate assertion failure at 45 ns, exactly one action; plus the six APB controls above |
| Functional covergroups / exported report | Licence-blocked | Licence-blocked; no UCDB or exported functional coverage report |

[Original ModelSim probes](probes/original-modelsim/feature-results.json),
[original Questa probes](probes/original-questa/feature-results.json), and
[source-identified extended probes](probes/qualified-questa/feature-results.json)
include actual commands, versions, outputs and source hashes. The explicit
expected assertion action is in [the SVA execution log](probes/qualified-questa/sva/2.log).
The capability wrapper exits **1**, because not every requested feature passed.

All three coverage-enabled UVM adapter builds compile with zero errors/warnings.
Loading each simulation fails at time zero on the actual `svverification`
licence check; [coverage-mode JSON](coverage-blocked/results.json) records the
adapter simulations **NOT RUN / LICENCE_BLOCKED**, six independent assertion
controls PASS, and **wrapper exit 1**. Coverage export is NOT RUN because no
covergroup simulation produced a database. The covergroup model is compiled,
but its sampling, bins, report export and closure remain unvalidated at runtime.
`requirements.json` files are explicitly **procedural requirement hits, not
simulator functional coverage**.

The [two original advanced environments](ORIGINAL_ENVIRONMENTS.json) require
the blocked features. They were preserved and not rerun with unsupported
features removed. They remain **NOT RUN**. The new UVM result does not qualify
their original randomization or coverage environments.

## Failure detection

The explicit adapter `+FAULT_READ` control flips bit zero of an accepted
address-zero read. The independent scoreboards each raised exactly one
`ORACLE_DATA` UVM fatal: 45 ns for each real DUT, 65 ns for the synthetic
responder. Although each simulator process exited 0, the combined project
wrapper exited **1**. No positive marker appeared for a faulted adapter.
[Raw failed regression](fault-read-data/results.json) and
[expected-detection qualification](fault-read-data/FAULT_QUALIFICATION.json)
keep that distinction explicit. The six assertion controls still passed.
A [missing-tool control](missing-tool-control/results.json) also returned 1
with every requested substep NOT RUN.

Preliminary attempts are retained separately: a CRLF result-marker parser bug,
a covergroup construction compile failure, and a node-locked licence contention
run. Those failures were corrected or rerun serially; they are not positive
evidence. An [initial UVM ini-path configuration error](probes/initial-uvm-ini-failure/feature-results.json)
was resolved by supplying the installed matching library/header paths directly;
it is not described as a UVM feature licence failure.

## Measured waveforms and bytes

The three raw VCDs in `clean-positive/adapter-*/capture.vcd` come from the
passing UVM simulations. Five figures show [address aliasing](waveforms/adapter-0-alias.svg),
[asynchronous setup abort](waveforms/adapter-0-reset.svg),
[invalid-address error](waveforms/adapter-1-error.svg),
[two-cycle waits](waveforms/adapter-2-wait.svg), and
[asynchronous reset during a pending write wait](waveforms/adapter-2-reset.svg).
The crops are selected from actual signal events, not idealized diagrams.
[Figure manifest](waveforms/MANIFEST.json) records exact tick ranges, source
revision, renderer revision/hash and capture hashes. The independent UVM
scoreboard and assertion logs determine results; the renderer does not.

All new report files use scoped Git `-text` attributes. Original-capture bytes
are the committed representation, with CRLF retained where emitted. No newline
conversion or simulation-behavior claim is involved. The
[publication byte audit](BYTE_AUDIT.json) passed for all 14 new VCDs (including
preliminary/fault evidence) and five current figure metadata files at evidence
revision `49870d98ab7a31ac980d6e0e78819bf0c1d7e429`: Git blobs, public raw
downloads and fresh detached checkouts with `core.autocrlf=false` and `true`
matched. Historical VCDs/manifests elsewhere in the repository were not rewritten.

## Reproduce

The following uses the tested source and fresh paths. Run simulator commands
**serially**: this installed node-locked Starter licence allows one session.

```powershell
git -c core.longpaths=true -c core.autocrlf=false clone --branch advanced/apb-uvm-milestone https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\apb-uvm-reproduce-new
git -C C:\short\apb-uvm-reproduce-new checkout --detach ff158f4f7ed844f2a7ab9b3e19423ebc50be8f60
python C:\short\apb-uvm-reproduce-new\scripts\run_apb_uvm.py --sim-bin C:\MXR\Quartus\25.1\questa_fse\win64 --uvm-lib C:\MXR\Quartus\25.1\questa_fse\uvm-1.2 --uvm-include C:\MXR\Quartus\25.1\questa_fse\verilog_src\uvm-1.2\src --output C:\short\apb-uvm-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required UVM/SVA substep failed or was blocked' }
```

The executed Python binary was `C:\Users\CG\AppData\Local\Python\bin\python.exe`;
all process argument lists and working directories are recorded in the JSON.
Use `--mode coverage` in a fresh directory after obtaining a suitable licence;
the wrapper must remain nonzero while a required coverage substep is blocked.
See [the guide](../../docs/ADVANCED_APB.md) for the feature probe command and
per-requirement mapping. Run the original `scripts/run_sim.ps1` environments
only after their features qualify, in disposable clones because those original
scripts write to their own `reports/` paths.

## Remaining scope

Functional coverage collection/export and model runtime validation, constrained
random APB sequences, broader reset-phase/back-to-back coverpoints and coverage
closure remain future work. The current transactions and assertions describe
these bounded RAM contracts; they do not establish full APB compliance, full
portfolio UVM, complete RV32I ISA, synthesis, timing, FPGA or hardware results.
The portable release and original labs remain separate and intact.
