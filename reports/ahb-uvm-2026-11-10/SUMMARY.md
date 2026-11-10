# Deterministic AHB-Lite RAM UVM/SVA - fresh detached source evidence

This is a separate review milestone. Implementation and adapter PRs remain open,
unmerged. It changes no production DUT RTL or prior release source lock/report.

## Exact sources and execution

- Environment: `d403d88a71e7c55a46641366007ebd0af9e444a4`; clean detached normal GitHub clone.
- Runner last change: `48437f440cbd1b10b4abc73c254363ad9c6a06fa`.
- Inventory last change: `f49314d214da41400b9155dd86207da6764ddeec`.
- DUT: `659fba67ce85a01643cceca2c8d1e67ea3903995`; freshly cloned from GitHub, detached, byte-checked, clean afterward.
- Questa: `Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025`; runtime `QUESTA_UVM-1.2.3`.
- Seed: `0x28A6BEEF` / 682016495. Sessions executed serially.
- Required substeps: **43/43 PASS**; actual aggregate and outer wrapper exit **0**.

[Raw results](run/results.json), [actual outer wrapper receipt](wrapper-receipts/fresh-v3-wrapper.json),
[console](wrapper-receipts/fresh-v3-wrapper.log), [source/input locks](SOURCE_LOCKS.json),
[validation](VALIDATION.json), and [named inventory](TEST_INVENTORY.json) are preserved.
The publication commits following the tested environment only add documentation/evidence.
[Vendor/configuration fingerprints](VENDOR_INPUTS.json) were captured during the
initial fresh attempt and rechecked unchanged after the final corrected run. Proprietary tool/library
contents are not redistributed. Shared execution code and other AMBA environments
were unchanged; those completed releases were not rerun or relabelled.
The collector checked 186 recorded command-log hashes against raw bytes.

The counted Questa warning is `vopt-10908` from `+acc`; a separate `onerror` macro
warning is also in the raw logs. Expected-negative controls intentionally report
their named detections/fatals. They are not zero-error functional simulations.

## Results and accounting

23 reset-isolated SVA controls (15 precise negatives and eight legal
exceptions), 6 isolated scoreboard controls (four expected
fatals and two legal/reset controls), two functional groups, 11 fault parents, and
one portable gate comprise the 43 required substeps. The smoke plus main functional
group executed **45 scenarios / 10,497 comparisons**.
No assertion detection occurred in ordinary functional DUT traffic.

| Actual functional quantity | Result |
| --- | ---: |
| Offered requests | 1896 |
| Accepted addresses | 1879 |
| Successful retirements | 1858 |
| ERROR retirements | 17 |
| Successful writes / reads | 766 / 1092 |
| Withdrawn speculative requests | 16 |
| Reset cancellations, accepted / not accepted | 4 / 1 |
| Global wait edges / overlapping retire-accept edges | 65 / 1700 |
| Observed resets | 50 |

Each case reconciles intentions, address acceptance, data retirement and reset
cancellation; the runner checks the relationships and exact named schedule totals.
Expected memory is independent of observed addresses and DUT internals. See the
[requirements/checkers matrix](../../docs/DETERMINISTIC_AHB_UVM.md#requirements-matrix).
The ignored-unselected case specifically reproduces a pending selected read retiring
with live HSEL=0. Adapter documentation clarifies the old ambiguous zero-read sentence;
there is no RTL defect or RTL change.

## Fault qualification

| Fault | Required diagnostic | Child wrapper exit | Parent qualification |
| --- | --- | ---: | --- |
| `fault-live_address` | `READ_DATA` | 1 | PASS |
| `fault-address_phase_data` | `READ_DATA` | 1 | PASS |
| `fault-read_data` | `READ_DATA` | 1 | PASS |
| `fault-invalid_write` | `READ_DATA` | 1 | PASS |
| `fault-wait_advance` | `READ_DATA` | 1 | PASS |
| `fault-short_error` | `SVA:ERROR_FIRST` | 1 | PASS |
| `fault-missing_error` | `SVA:EP_ZERO_WAIT` | 1 | PASS |
| `fault-address_alias` | `ADDRESS_INTENT` | 1 | PASS |
| `fault-duplicate` | `UNSOLICITED_ADDRESS` | 1 | PASS |
| `fault-omit_observation` | `ADDRESS_INTENT` | 1 | PASS |
| `fault-missing_marker` | `MISSING_RESULT_MARKER` | 1 | PASS |

Every fault has an unmodified passing functional control in the full run. Seven
mutations are compiled separately from the unchanged locked checkout; exact diffs
and original/compiled hashes are in child directories. Test-only driver/monitor/
program shims are named. The duplicate repeats a legal write to address zero with
the same `0x1265abcd` data after a checked write/read, without another intention;
the ownership oracle rejects it. Omission is a deliberately dropped observation,
not a production monitor behavior. Missing-marker proof retains real functional
completion but makes the child wrapper fail. No unrelated compile failure, crash
or timeout is accepted as fault detection.

## Portable gate and staged execution

The preserved `scripts/run_regression.ps1` at the DUT lock passed **924 pin
comparisons**, 139 accepted addresses, 135 retired, 40 commits, 12 errors and nine
stalls; its negative suite passed **three malformed-master cases and one legal
hold**, wrapper exit 0. Simulator: `Model Technology ModelSim - INTEL FPGA STARTER EDITION vsim 2020.1 Simulator 2020.02 Feb 28 2020`.
It retains its separate seed `0x28A81607`. Raw portable results are under
[run/portable/run](run/portable/run/results.json). The inherited obsolete single-cycle
ERROR bench was not used as the current contract oracle.

Targeted controls ran before smoke, full named cases, faults and the portable gate.
The initial standalone checker attempt failed elaboration because the package's
virtual-interface type had no top-level instance. That failed run is preserved in
`development/ahb-test-controls-v1`; the interface-anchor fix and passing repeat are
in `development/ahb-test-controls-v2`. These are development attempts, not extra
passing coverage. Later strengthened counting records every assertion occurrence.
The first fresh attempt was intentionally stopped during checker qualification
when pre-publication review found unrelated/same-address requests labelled SEQ.
That attempt is preserved under `development/first-fresh-interrupted`, outer exit 1,
with no full milestone PASS. The corrected generator uses NONSEQ for independent
requests and SEQ only for incrementing word continuations with unchanged direction/
size. BUSY examples now begin in an active sequence and retain its next address.
[Stimulus review](STIMULUS_REVIEW.json) compares actual old/new public-pin captures: 36 old sequencing violations, zero corrected. The separate `check_stimulus_captures.py` accepts explicit repository, old/corrected run directories and a fresh output path; it is a stimulus audit, not a full burst-compliance checker.
The targeted functional/fault/portable stages were rerun before the final fresh
43-substep execution. A subsequent corrected-source fresh run passed all 43
substeps, but its detached checkout inherited global CRLF conversion. The input
byte audit identified 11 newline-only differences; that real pass is preserved under
`development/fresh-v2-crlf-passing` with its original hashes. Clone configuration was
made persistent and the final canonical-byte run repeated all 43 substeps. No
simulation-behavior change is attributed to newline conversion. Earlier passing endpoint-only development runs are superseded
by this corrected stimulus, not evidence of general burst compliance.

## Measured waveforms and bytes

[Four measured figures and metadata](waveforms/MANIFEST.json) show full-rate write
pairing, five global read stalls with changing HWDATA, ERROR/cancellation and held
completion, and reset of an accepted stalled write plus an unaccepted address.
The renderer checks the displayed public-pin events against the actual VCD. The
figures are measurements; no expected diagram is presented as a capture.

[CAPTURE_MANIFEST.json](CAPTURE_MANIFEST.json) hashes exact original artifact bytes.
The report's scoped `.gitattributes` applies `-text` to preserve capture/log newlines.
Original-capture and committed-byte representations are deliberately identical;
figure metadata/captions name and hash those bytes. Publishing does not attribute
any simulation-behavior change to newline conversion. A separate byte-audit receipt
checks Git blobs, raw VCD downloads and clean detached checkouts with conversion
both disabled and enabled.

## Reproduce

Use unused short destinations. The exact command actually executed is in the
outer wrapper receipt above; this procedure selects the same published source.
The qualified Questa/UVM paths and separate ModelSim installation must exist.

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\ahb-uvm-reproduce-new
git -C C:\short\ahb-uvm-reproduce-new checkout --detach d403d88a71e7c55a46641366007ebd0af9e444a4
& $python C:\short\ahb-uvm-reproduce-new\scripts\run_ahb_uvm.py --expected-env-sha d403d88a71e7c55a46641366007ebd0af9e444a4 --output C:\short\ahb-uvm-run-new
if ($LASTEXITCODE -ne 0) { throw 'Required AHB milestone failed or was blocked' }
```

## Remaining limits

Functional coverage, constrained randomization and the original licence-blocked
advanced ALU/APB environments remain **NOT RUN**. This directed requirements matrix
is not a functional-coverage report. Full AHB compliance, HBURST/interconnect
expansion, new transfer sizes, coverage closure, synthesis, timing, FPGA and
hardware remain separate milestones. Bounds are test assumptions, not AHB latency
requirements. Existing licences, notices, attribution and `LICENSE_STATUS.md`
remain in force; no new licence is assigned to the inherited AHB source.

## Published-byte audit completed

Evidence commit `71f2505d9dcc29d990859a4dad6825e9d3267906` was audited before adding this receipt.
[BYTE_AUDIT.json](BYTE_AUDIT.json) verifies 1375 original artifacts
against Git blobs and fresh detached checkouts with `core.autocrlf=false` and `true`.
All 52 captured VCDs match public raw downloads; four figure
metadata files and captions identify those exact original bytes.
[Commands and exits](BYTE_AUDIT_COMMAND.json) are retained. This receipt changes
no execution input, original capture or historical evidence.
