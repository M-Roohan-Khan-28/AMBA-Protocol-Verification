# Deterministic AXI4-Lite UVM/SVA — 8 November 2026

**17/17 required substeps PASS; wrapper exit 0**, reproduced from a fresh
detached GitHub clone. This is a separate milestone published for review.
Coverage and constrained randomization are **NOT RUN**; no coverage percentage
or export is claimed. The completed eleven-project portable release and the
merged APB UVM/SVA milestone remain intact.

## Exact source and tool configuration

- Tested AMBA implementation, runner, lock-file and waveform-selector revision:
  **`3da848965b00f97d7488e4b98e362cf21f67644d`**.
- AMBA main baseline: `d826c798bc7c1d07204a2db414128f6f0774d0fe`.
- Actual DUT lock: **`faf43379b24a524999eb2c8ad7e100cde35054c3`** in
  `M-Roohan-Khan-28/AXI4-Lite-Memory-Interface`. Each run fetched a fresh clone,
  detached at that full SHA, verified the observed revision and clean tree,
  and hashed all five compiled RTL files.
- Shared process helper remains at its existing last-change revision
  `6d53f6b840529aec272844a701eaab6650e748ec`; it was not edited.
- Simulator: **Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator
  2025.05 May 31 2025**. Installed precompiled UVM 1.2 and matching headers;
  runtime identifies `QUESTA_UVM-1.2.3`. No vendor library is redistributed.
- Seed: **682016495 (`0x28A6BEEF`)**. All sequences are deterministic; no
  `randomize()` or covergroup is invoked. Sessions ran serially.

[Published-clone results](published-clean/results.json),
[actual wrapper result](published-clean/WRAPPER_RESULT.json),
[wrapper console](published-console.log), and
[clean local source results](source-clean/results.json) record exact commands,
versions, input hashes, source locks and real exits. Both passing source trees
were clean. Later evidence/documentation commits do not alter these tested inputs.

## Actual positive results

| Target | Completed transactions | B completions | R completions | Independent value comparisons | Resets | Canceled transactions |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| UVM initiator → RTL slave/SRAM | 274 | 74 | 200 | 1,577 | 7 | 5 |
| UVM responder → RTL master | 240 | 72 | 168 | 1,207 | 6 | 4 |
| Existing RTL master/slave/SRAM integration | 208 | 72 | 136 | 1,044 | 4 | 2 |

Comparisons include repeated checks while responses are held. They are not
unique requirements or coverage percentages. Positive runs had zero UVM
errors/fatals and zero assertion detections. CPU acceptance/completion and
sequence/driver counts passed exactly-once checks; no transaction remained
pending at the end. All 17 compilations reported zero errors/warnings. Each
simulation reported zero errors and one counted `vopt-10908` warning from
`+acc`, plus the separate `onerror` macro-use warning. Raw logs are unfiltered.

The slave observed 25 address-first, 24 data-first and 26 simultaneous writes
at first BVALID, including one committed write whose held response was canceled
by reset. The master responder observed 24 of each ordering. Integration
observed 72 simultaneous writes through its original wiring. All three targets
observed all 16 strobe masks, eight invalid writes, eight invalid reads, all 16
initialized words and reset-retained data. The slave observed 6 AW stall cycles,
6 W stall cycles, 157 B stall cycles and 473 R stall cycles. The controlled
master responder observed 197 AW, 197 W and 452 AR stall cycles. These are
procedural requirement hits in each adapter's `requirements.json`, not
functional coverage. The master/integration has no external response-stall knob.

## Executed assertion qualification

Fourteen additional simulations are included in the 17-substep total:
thirteen malformed traces, each reset-isolated and identified by case number,
plus one legal ordering/backpressure trace. Every negative produced exactly
one required named detection; the legal case produced zero. Each wrapper
qualification entry verifies both the completion marker and exact detection ID.

| Cases | Expected detections |
| --- | --- |
| 0–4 | AW_HOLD, W_HOLD, AR_HOLD, B_HOLD, R_HOLD, one per case |
| 5–8 | B_ELIGIBILITY: neither request channel, AW-only, W-only, same-edge missing W |
| 9–10 | R_ELIGIBILITY: no AR with READY low; same-edge AR |
| 11–12 | B_ELIGIBILITY: same-edge missing AW; same-edge AW and W |
| 13 | Legal address-first, data-first, simultaneous and held responses: no detection |

The assertions and passive scoreboard check response eligibility when VALID is
sampled, including READY-low cycles, before accepting the current edge's
dependencies. See the [implementation/requirements guide](../../docs/DETERMINISTIC_AXIL_UVM.md).

## Real failure evidence

| Deliberate control | Observed cause | Simulator exit | Wrapper exit |
| --- | --- | ---: | ---: |
| [Read-data bit flip, all three targets](fault-data/FAULT_QUALIFICATION.json) | ORACLE_DATA for slave; CPU_DATA for master and integration | 0 each | **1** |
| [Altered master AWADDR](fault-address/FAULT_QUALIFICATION.json) | REQUEST_ADDRESS at 75 ns | 0 | **1** |
| [Dropped master read response](fault-progress/FAULT_QUALIFICATION.json) | PROGRESS at 2,380 ns, exceeding 80 sampled cycles | 0 | **1** |

All five faulted simulations were rejected for their intended reason; none
printed a positive result marker. The controls alter only verification-boundary
signals. No original RTL was mutated. [Campaign record](fault-campaign.json)
and the three separate failed-run directories retain real logs and commands.
UVM fatal handling can leave the simulator process at exit 0; the wrapper
checks the log and returns nonzero, as these runs demonstrate.

The first address-fault attempt was **NOT RUN**, wrapper exit 1, because GitHub
reset the clone connection. Its [actual clone error](preliminary/address-fault-clone-blocked/source-0.log)
and results remain separate; the successful fault detection used a fresh retry
directory. Earlier development records retain a virtual-method argument-name
compile error, interface initialization/continuous-driver errors, a diagnostic
pass, and an earlier 15-substep pass with a static-declaration warning. They are
not the final 17-substep evidence. [Publication attempt records](publication-attempts.json)
separately describe a DNS failure before the first branch push and the resulting
missing-branch clone; a verified owner retry later succeeded.

## Measured waveforms and byte provenance

The three current `published-clean/adapter-*/capture.vcd` files are direct
simulator outputs. [Eight measured figures](waveforms/MANIFEST.json) show
AW/W orderings, B backpressure, partial-write reset, independent master stalls,
read/CPU completion and integrated byte strobes. The figures are selected from
real signal events; they are not expected diagrams. Same-timestamp changes
display their final value, as labelled; use the simulator for delta-cycle
analysis. The scoreboards and assertions determine PASS, not the renderer.

[Capture manifest](CAPTURE_MANIFEST.json) maps 276 archived artifacts to original
files and SHA-256 hashes. Scoped Git `-text` attributes retain exact capture
bytes, including CRLF. Current figure metadata records source revision,
renderer revision/hash, original capture hash, representation and tick range.
Publication byte verification is recorded separately after the public push.
No newline-only simulation-behavior change is claimed. Historical reports in
other directories are untouched; [preservation checks](PRESERVATION.json) record
the unchanged prior runners, locks, probes and evidence.

## Reproduce

This source and one-command regression were executed successfully. Use unused
short paths; the output directory must not exist. Run one simulator at a time.

```powershell
git clone --config core.longpaths=true --config core.autocrlf=false --branch advanced/axil-deterministic-uvm https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:/short/axil-uvm-reproduce-source
git -C C:/short/axil-uvm-reproduce-source checkout --detach 3da848965b00f97d7488e4b98e362cf21f67644d
& 'C:/Users/CG/AppData/Local/Python/bin/python.exe' C:/short/axil-uvm-reproduce-source/scripts/run_axil_uvm.py --output C:/short/axil-uvm-reproduce-results
if ($LASTEXITCODE -ne 0) { throw 'Required deterministic AXI4-Lite UVM/SVA substep failed or was blocked' }
```

Defaults select `C:/MXR/Quartus/25.1/questa_fse/win64`, its `uvm-1.2` library
and `verilog_src/uvm-1.2/src` headers. The JSON records the resolved Python
interpreter, exact commands and original execution paths. The runner emits raw
VCDs; generate the measured figures with:

```powershell
python scripts/render_axil_uvm_waves.py --run C:/short/axil-uvm-reproduce-results --output C:/short/axil-uvm-reproduce-figures
```

## Remaining limits and NOT RUN work

This is a bounded 16-word, 32-bit, single-clock AXI4-Lite milestone. It does not
claim every parameter value, overlapping read/write arbitration, multiple
outstanding requests, every reset/commit permutation, all response encodings,
PROT policy, full protocol compliance, synthesis, timing, FPGA or hardware.
The master launches AW/W together and exposes no completion-ready or external
B/R backpressure control. The integration is tested with its existing wiring.

Functional coverage and constrained randomization are **NOT RUN** here. Their
features were licence-blocked by the preserved APB milestone probes; those probes
were not rerun in this task. This deterministic AXI environment contains no
executed covergroups or random sequences, and has no functional coverage export.
The original advanced ALU/APB environments remain **NOT RUN**. Extending the
requirements into a measured covergroup model, randomized sequences and closure
requires a suitable feature licence and separate qualification. No new
eleven-project aggregate or changed result for the APB milestone is claimed.
