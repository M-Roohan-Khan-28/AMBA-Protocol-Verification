# AHB runner process-exit correction - fresh detached evidence

This focused correction updates open AMBA PR #14 and companion AHB documentation
PR #3. Both remain unmerged. DUT RTL, UVM/SVA HDL, deterministic stimulus,
mutation definitions, DUT lock, prior releases and historical reports are unchanged.
The [original 43-substep report](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/blob/faf8291b5d7b40362f30c79f12ed49453158dfc4/reports/ahb-uvm-2026-11-10/SUMMARY.md) and its measured figures remain intact.

## Defect and correction

The previous SVA fault-parent branch checked its intended assertion and fatal text
but omitted the simulator process exit check. The common production
`qualify_fault` function now requires exactly three completed tool commands
(vlib, vlog, vsim), each with exit **0** and no timeout, for every fault kind.
The expected **child wrapper exit is 1**. These separate outcomes cannot substitute
for one another. Source/input identity, exact diagnostic, unrelated-error rejection,
mutation hashes, missing-marker checks and bounded execution remain enforced.

The executable fixture suite imports this production function. Its old comparison
extracts and executes the unchanged guard AST from locked historical runner
`faf8291b5d7b40362f30c79f12ed49453158dfc4`, checks that blob's SHA-256, and replaces only its file-loading prelude
with the fixture arguments. It does not independently reimplement the predicate.
The historical child records retain environment
`d403d88a71e7c55a46641366007ebd0af9e444a4` and DUT `659fba67ce85a01643cceca2c8d1e67ea3903995`.

## Runner qualification fixtures - not HDL crashes

**48/48 fixture checks PASS**, separately from HDL counts.
For each published `fault-short_error` and `fault-missing_error` child:

| Record variant | Historical qualifier | Corrected qualifier |
| --- | --- | --- |
| Original vsim exit 0 and intended diagnostic | ACCEPT | ACCEPT |
| Only vsim exit changed to 211 | ACCEPT | REJECT |
| Only vsim exit changed to 127 | ACCEPT | REJECT |
| Only vsim exit changed to -11 | ACCEPT | REJECT |
| Simulator timeout or incomplete command list | REJECT | REJECT |
| Missing simulator exit field | ACCEPT | REJECT |

Each of four original records (two SVA, one UVM fatal, one missing-marker) has
twelve variants. Additional cases reject library/compiler failures, compiler
timeout, source mismatch and unrelated diagnostics. The genuine UVM-fatal and
missing-marker baseline records still qualify. Full [old/new decisions and input
identities](full-run/runner-qualification/run/results.json), changed-record fixtures
and [raw qualification log](full-run/runner-qualification/qualification.log) are preserved.
These are edited runner records, **not actual induced simulator crashes**.

A disposable committed checkout substitutes the historical qualifier in the fixture
test only. Eight of 48 checks fail, making the required qualification substep and
project aggregate/outer wrapper exit **1**. This is a selected-substep gate control,
not a second full HDL regression. [Control results](gate-control/results.json),
[fixture failures](gate-control/runner-qualification/run/results.json),
[exact diff](receipts/gate-control-v2.diff) and [wrapper receipt](receipts/gate-control-v2.json)
preserve the proof. The disposable mutation was not pushed.

## Exact tested revisions and order

- Environment: `3eb0e520a880b2cfb13d304bbeea119dbe917fb3`; clean fresh normal GitHub clone, explicit detached checkout.
- Runner last change: `3eb0e520a880b2cfb13d304bbeea119dbe917fb3`.
- Inventory last change: `33f33d6034165085833d5f16390f6a625d15a2bc`.
- Unchanged DUT: `659fba67ce85a01643cceca2c8d1e67ea3903995`; fresh detached GitHub source clone, clean after execution.
- Questa: `Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025`; runtime `QUESTA_UVM-1.2.3`.
- Seed: `0x28A6BEEF` / 682016495. All simulator sessions executed serially.

Execution order: required runner-fixture qualification, disposable gate control,
the two real targeted SVA-fault simulations, then the complete fresh-clone suite.
Both targeted faults qualified with **tool exits [0, 0, 0], child wrapper exit 1,
parent PASS**. `fault-short_error` detected only `SVA:ERROR_FIRST`;
`fault-missing_error` detected only `SVA:EP_ZERO_WAIT`.
[Targeted raw results](targeted-sva/results.json) and [actual outer exit 0](receipts/targeted-sva-v2.json)
are separate from fixture evidence.

## Complete required workflow

The inventory preserves all original 43 substeps and adds one required
`runner-qualification` entry: **44/44 required PASS**,
aggregate and actual outer wrapper exit **0**. It retains 23 SVA controls,
six scoreboard controls, two functional groups, 11 fault parents and one portable gate.
The separate runner substep executes 48 fixture checks.

The HDL functional results remain **45 scenarios /
10,497 independent comparisons**. Every per-case result matches the
original successful run: 1896 intentions, 1879 accepted addresses,
1858 successful retirements, 17 ERROR retirements,
16 speculative withdrawals, reset cancellations of 4
accepted and 1 unaccepted requests, 766 writes,
1092 reads and 1700 overlapping retire/accept edges.
Request/retirement/reset accounting reconciled. These counts are not combined coverage.

| Real fault control | Exact required diagnostic | Child wrapper | Tool exits | Parent |
| --- | --- | ---: | --- | --- |
| fault-live_address | `READ_DATA` | 1 | [0, 0, 0] | PASS |
| fault-address_phase_data | `READ_DATA` | 1 | [0, 0, 0] | PASS |
| fault-read_data | `READ_DATA` | 1 | [0, 0, 0] | PASS |
| fault-invalid_write | `READ_DATA` | 1 | [0, 0, 0] | PASS |
| fault-wait_advance | `READ_DATA` | 1 | [0, 0, 0] | PASS |
| fault-short_error | `SVA:ERROR_FIRST` | 1 | [0, 0, 0] | PASS |
| fault-missing_error | `SVA:EP_ZERO_WAIT` | 1 | [0, 0, 0] | PASS |
| fault-address_alias | `ADDRESS_INTENT` | 1 | [0, 0, 0] | PASS |
| fault-duplicate | `UNSOLICITED_ADDRESS` | 1 | [0, 0, 0] | PASS |
| fault-omit_observation | `ADDRESS_INTENT` | 1 | [0, 0, 0] | PASS |
| fault-missing_marker | `MISSING_RESULT_MARKER` | 1 | [0, 0, 0] | PASS |

The unchanged portable gate passed **924 pin comparisons**, three malformed-master
controls and one legal hold, wrapper exit **0**, with ModelSim Intel FPGA Starter
Edition `vsim 2020.1 Simulator 2020.02 Feb 28 2020`, seed `0x28A81607`.
All necessary tools completed successfully; expected negative diagnostics were
checked individually. No unexpected simulator failure qualified.

[Full raw results](full-run/results.json), [actual wrapper command/exit](receipts/fresh-wrapper-v2.json),
[wrapper console](receipts/fresh-wrapper-v2.log), [source/input locks](SOURCE_LOCKS.json),
[validation](VALIDATION.json), [command-log hash audit](COMMAND_HASH_AUDIT.json) and
[qualified vendor-input fingerprints](VENDOR_INPUTS.json) are preserved.
Evidence/documentation commits after the tested source change no execution inputs.
Shared execution code was unchanged, so unrelated portfolio environments were not rerun.

## Development attempt retained

The first fresh run at `33f33d6034165085833d5f16390f6a625d15a2bc` found that the
new success-marker regex rejected the trailing CR in Windows subprocess output,
although its 48 fixture checks passed. The run was stopped after that required
failure and recorded actual outer exit 1; it is **not a complete passing run**.
[Its partial results](development/ahb-fix-fresh-run-20261110/results.json) and
[interruption receipt](receipts/first-fresh-interruption.json) remain separate.
The final runner accepts trailing whitespace and requires exactly one marker
whose count matches the JSON. The fixture gate, its failure control and both real
targeted simulations were repeated before the final full run.

## Waveforms and byte provenance

The [existing measured figures](https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification/blob/faf8291b5d7b40362f30c79f12ed49453158dfc4/reports/ahb-uvm-2026-11-10/waveforms/MANIFEST.json) remain linked to
their original captures. No figure has been reassigned to this execution.
New raw simulator VCDs are published with [original capture hashes](CAPTURE_MANIFEST.json).
Scoped Git `-text` preserves exact log/capture bytes without newline conversion.
A separate published-byte audit verifies Git blobs, public raw VCD downloads and
fresh detached checkouts with conversion both disabled and enabled. Fixture JSON
is explicitly labelled and is not treated as a real process execution record.

## Reproduce

Use unused destinations and the qualified installed tool paths. The receipt above
records the actual executed argv; this procedure selects the identical tested source.

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\ahb-corrected-source-new
git -C C:\short\ahb-corrected-source-new checkout --detach 3eb0e520a880b2cfb13d304bbeea119dbe917fb3
& $python C:\short\ahb-corrected-source-new\scripts\run_ahb_uvm.py --expected-env-sha 3eb0e520a880b2cfb13d304bbeea119dbe917fb3 --output C:\short\ahb-corrected-output-new
if ($LASTEXITCODE -ne 0) { throw 'Required AHB milestone failed or was blocked' }
```

## Remaining status

Both PRs stay **open and unmerged for review**. Functional coverage, constrained
randomization and original licence-blocked advanced ALU/APB remain **NOT RUN**.
Full AHB compliance, burst/interconnect expansion, new sizes, coverage closure,
synthesis, timing, FPGA and hardware remain separate milestones. Existing licences,
attribution, source history and all completed release evidence are preserved.
