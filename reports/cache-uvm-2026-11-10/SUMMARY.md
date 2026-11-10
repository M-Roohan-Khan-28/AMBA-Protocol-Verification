# Deterministic cache UVM/SVA — fresh detached GitHub validation

**Ready for review; not merged.** New isolated milestone, 10 November 2026.

## Exact identities and execution

- Owner: M-Roohan-Khan-28, immutable ID 270144410.
- Tested AMBA source: `9c74c35e0c2616a09af8824d2d85754738b5303a`.
- Runner last-change: `9c74c35e0c2616a09af8824d2d85754738b5303a`.
- Inventory last-change: `9c74c35e0c2616a09af8824d2d85754738b5303a`.
- Unchanged cache DUT lock: `b6246eff1380aa0fb7812de9fccaf12b849fa1ca`.
- Simulator: `Questa Altera Starter FPGA Edition-64 vsim 2025.2 Simulator 2025.05 May 31 2025`; runtime `QUESTA_UVM-1.2.3`.
- Seed: `0x28A6BEEF` / 682016495; deterministic stimulus, no randomization.
- Fresh source clone: `C:/short/cache-uvm-fresh-20261110`, explicitly detached.
- Fresh output: `C:/short/cache-uvm-fresh-run-20261110`.
- Actual outer wrapper exit **0**, aggregate exit **0**, **20/20 named required substeps PASS**.
- Environment/DUT clean after execution; all full-SHA locks and input hashes matched.

The counted vendor warning is `vopt-10908` from `+acc`; the separately printed
`onerror` warning is also retained. Neither is an assertion result.

## Actual observations

**79 named HDL scenarios**, including all 64 way/set/tag combinations
and all 256 byte values at a representative entry, produced **10,222
independent hit/data comparisons** over **5,111 settled observations**.
These are procedural measurements, not a coverage percentage.

```text
5111 lookups = 1566 hits + 3545 misses
10222 comparisons = 2 × 5111 observations
420 rising clocks; 402 allowed write commits; 2 reset-blocked write clocks; 87 asynchronous reset edges
```

Every case's counts match a separate Python public-pin schedule ledger.
The scoreboard computes expected values from independent valid/tag/data arrays.
Neither oracle reads DUT storage or outputs to construct expected data.

| Required substep | Result | Actual outcome |
| --- | --- | --- |
| `runner-qualification` | PASS | 27 synthetic record fixtures |
| `sva-reset` | PASS | RESET_DOMINANCE |
| `sva-write` | PASS | SELECTED_WRITE |
| `sva-hit` | PASS | LOOKUP_HIT |
| `sva-miss` | PASS | MISS_ZERO |
| `sva-stored` | PASS | STORED_ENTRY |
| `sva-duplicate` | PASS | DUPLICATE_PRIORITY |
| `sva-legal` | PASS | legal compound control; zero detections |
| `smoke` | PASS | 1 cases; 82 comparisons |
| `functional` | PASS | 78 cases; 10140 comparisons |
| `fault-wrong_way` | PASS | child wrapper 1; tools 0/0/0; CACHE_DATA |
| `fault-wrong_set` | PASS | child wrapper 1; tools 0/0/0; CACHE_HIT |
| `fault-wrong_tag` | PASS | child wrapper 1; tools 0/0/0; CACHE_HIT |
| `fault-corrupted_data` | PASS | child wrapper 1; tools 0/0/0; CACHE_DATA |
| `fault-wrong_priority` | PASS | child wrapper 1; tools 0/0/0; CACHE_DATA |
| `fault-false_hit` | PASS | child wrapper 1; tools 0/0/0; CACHE_HIT |
| `fault-missing_reset` | PASS | child wrapper 1; tools 0/0/0; CACHE_HIT |
| `fault-forbidden_reset_write` | PASS | child wrapper 1; tools 0/0/0; CACHE_HIT |
| `fault-missing_marker` | PASS | child wrapper 1; tools 0/0/0; MISSING_RESULT_MARKER |
| `portable` | PASS | 7 legacy checks; 1,639 independent comparisons |

All nine fault parents require exact diagnostics, child-wrapper exit 1, and
three completed tool commands with exit 0 and no timeout. The fault children
remain recorded FAIL. Synthetic runner fixtures are labelled as modified
records, not induced simulator crashes. Earlier targeted controls and fault
runs remain under separate subdirectories with their actual source revisions.
No production RTL correction was needed.

The portable gate retains ModelSim 2020.1 results: **7 legacy checks** and
**1,639 contract comparisons**, 324 writes and two later resets, seed
`0x28CACE17`. Its result and logs are in `run/portable/`.

## Raw evidence and measured waveforms

- [Machine-readable full result](run/results.json), [actual wrapper receipt](fresh-wrapper.json), [wrapper log](fresh-wrapper.log).
- [Source/input locks](SOURCE_LOCKS.json), [validated accounting and fault outcomes](VALIDATION.json).
- [Original capture byte manifest](CAPTURE_MANIFEST.json), [figure source/crop manifest](WAVEFORMS.json).
- [Measured dual-way writes](waves/dual-way-writes.svg).
- [Measured duplicate-tag priority](waves/duplicate-priority.svg).
- [Measured asynchronous reset with pending write](waves/async-reset.svg).
- [Measured combinational lookup](waves/combinational-lookup.svg).

All figures are rendered from this run's actual simulator VCDs. Metadata and
captions use SHA-256 of the exact original captured bytes. The scoped `-text`
attribute preserves those bytes in Git and both newline-conversion checkout
modes. The byte audit is recorded separately. No newline-only difference is
claimed to change simulation behavior. Figures do not decide correctness;
the independent scoreboards/assertions and strict runner do.

## Reproduce

Use the qualified tool paths described in the [environment guide](../../docs/DETERMINISTIC_CACHE_UVM.md).
Choose unused source and output paths:

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\cache-uvm-source-new
git -C C:\short\cache-uvm-source-new checkout --detach 9c74c35e0c2616a09af8824d2d85754738b5303a
& $python C:\short\cache-uvm-source-new\scripts\run_cache_uvm.py --expected-env-sha 9c74c35e0c2616a09af8824d2d85754738b5303a --output C:\short\cache-uvm-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required cache milestone failed or was blocked' }
```

## Limitations and preservation

Functional coverage, constrained randomization and the original licence-blocked
advanced ALU/APB environments remain **NOT RUN**. Deterministic UVM and SVA
execution here does not imply those features ran. The known-output assertion
is exercised in legal runs; the six isolated negative controls target reset,
write, hit, miss, stored data and duplicate priority. No X-injection coverage
claim is made.

The supported endpoint is two ways/four sets with explicit way writes and
combinational lookup. Automatic replacement, refill, writeback, coherence,
full compliance, coverage closure, synthesis, timing, FPGA and hardware are
outside scope. Existing licences, attribution, DUT RTL, portable/legacy benches,
historical reports and all previous release inventories/runners remain intact.
