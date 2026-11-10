# Deterministic Two-Way Cache UVM/SVA contract

This separate environment tests the unchanged `Two-Way-Cache-RTL` source at
`b6246eff1380aa0fb7812de9fccaf12b849fa1ca`. It does not alter the completed
eleven-project, APB, AXI4-Lite, DMA or AHB milestones or their source locks.

## Implemented endpoint

Two ways, four sets, 3-bit tags and one 8-bit item per entry. `way_select`
chooses a write destination. An asserted `write` commits at each rising clock
unless active-high reset is asserted. Reset invalidates all entries
asynchronously and dominates coincident or later write clocks while held.
Lookup is combinational: a miss returns `hit=0,data_out=0`; matching entries
return stored data, with way 0 winning duplicate tags. `way_select` and
`data_in` may vary freely while `write=0`.

There is no handshake, automatic replacement, refill, writeback or coherence.
The arrays are not a cache controller for a CPU protocol. No obligations for
unimplemented interfaces are invented.

## Environment and sampling

`verification/cache_uvm/cache_uvm_pkg.sv` contains a UVM sequence item,
deterministic sequence, sequencer, driver, passive public-pin monitor,
scoreboard, environment and test. The top adapts the locked `cache_2way`
ports without changing the RTL. No expected value reads DUT internals.

The driver atomically updates packed public inputs at 5 ns-separated phases.
The passive monitor recognizes rising clock and reset events, snapshots the
input values, and samples outputs 1 ns later after NBA/combinational updates.
It reports all changed-input observations, including asynchronous lookup and
reset changes. Only clock edges commit modeled writes. Reset events clear
the independent valid/tag/data arrays; changing write inputs between clocks
cannot update reference storage. The scoreboard checks hit and data at each
observation. A separate Python schedule ledger reconciles observations,
clock/write/reset counts, hits, misses and comparisons per named case.

The assertion module independently models stored entries from public inputs.
Concurrent assertions evaluate on a delayed observation event 2 ns after the
public input update. This explicit simulation settle interval is a harness
assumption, not a hardware timing result. Reset, selected-write lookup,
hit/miss, known outputs, stored-entry preservation and way-0 duplicate priority
are checked. Storage preservation becomes observable through later lookups;
the assertions do not inspect internal arrays. The named negative controls
inject malformed output values only in a standalone checker harness.

## Requirements and deterministic inventory

| Requirement | Named cases / qualification |
| --- | --- |
| Every way/set/tag | `tuple_<way>_<set>_<tag>`: all 64 combinations, each followed by a 32-address scan |
| Full byte domain | `data_256`: all 256 values at way 1, set 2, tag 6 |
| Overwrite / isolation | `overwrite`, `entry_isolation`, scans after writes |
| Duplicate priority / reveal way 1 | `duplicate_0` through `duplicate_3` |
| Asynchronous lookup | `async_lookup` changes set/tag with clock low |
| No-write freedom | `no_write` changes data and way while write is inactive |
| Reset/write dominance | `reset_pending`, `reset_coincident` |
| Held writes | `held_writes` with writes on successive rising edges |
| Repeated reset / repopulation | `repeated_reset`, `post_reset_refill` |
| Basic integration | `smoke` |
| Assertion execution | Individually named negative controls and a legal compound scenario |
| Wrapper correctness | Synthetic record fixtures reject abnormal exits, timeouts, missing/mismatched diagnostics and source identities |

Functional results are per-case observations, not functional coverage bins.
The actual totals and input identities are recorded in the release report.

## Fault qualification

Disposable RTL copies introduce wrong way, set, tag, data, duplicate priority,
false hits, missing reset invalidation and writes forbidden by reset. A ninth
control requests an impossible mandatory completion marker while retaining
the real passing completion in the log. Original passing scenarios are kept.

A fault parent passes only when its child wrapper exits 1, the exact intended
diagnostic appears, all three `vlib`/`vlog`/`vsim` commands exit 0 without
timeout, source/input identities match, and no unrelated error occurs. The
fault child's output stays FAIL. Wrong-way selection is exposed by duplicate
priority because swapping ways without duplicates can preserve lookup data.

## Scope and provenance

Original RTL, legacy benches, portable tests, licences, notices and historical
reports remain unchanged. `SOURCE_PROVENANCE.json` retains extraction history;
the source repository remains the authority for original attribution. The
owner confirmed joint development and permission for reuse and enhancements.
No new licence is assigned to inherited material. UVM is supplied by the
installed qualified vendor library; proprietary libraries are not copied.

Functional coverage, constrained randomization and the original licence-blocked
advanced ALU/APB environments are **NOT RUN**. No full cache compliance,
replacement, refill, writeback, coherence, coverage closure, synthesis, timing,
FPGA or hardware result is claimed. The portable 7 legacy checks and 1,639
comparisons remain separate from UVM/SVA counts.

## One-command runner and tested reproduction

Use the installed qualified Questa 2025.2/UVM 1.2 setup. The defaults are
`C:/MXR/Quartus/25.1/questa_fse/win64`, vendor `uvm-1.2` library and
`verilog_src/uvm-1.2/src` include directory; override the three command-line
options together only for a separately qualified installation. The portable
gate uses `C:/intelFPGA/20.1/modelsim_ase/win32aloem`. Python 3.9+ and Git are
required. Vendor libraries are not distributed here.

From unused short paths:

```powershell
$python = 'C:\Users\CG\AppData\Local\Python\pythoncore-3.14-64\python.exe'
git clone --config core.longpaths=true --config core.autocrlf=false https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\cache-uvm-source-new
git -C C:\short\cache-uvm-source-new checkout --detach 9c74c35e0c2616a09af8824d2d85754738b5303a
& $python C:\short\cache-uvm-source-new\scripts\run_cache_uvm.py --expected-env-sha 9c74c35e0c2616a09af8824d2d85754738b5303a --output C:\short\cache-uvm-results-new
if ($LASTEXITCODE -ne 0) { throw 'Required cache milestone failed or was blocked' }
```

The full runner requires a clean detached environment and full expected SHA.
It clones and detaches the cache DUT at its full lock, verifies file hashes,
runs every named substep serially, then checks unchanged input/worktree state.
Each command has a 90-second bound (portable wrapper 600 seconds), and the
complete invocation has a 3,600-second bound. HDL watchdogs bound simulation.
Missing tools, licence failures, timeouts, wrong/missing markers, unexpected
fatals or failed required suites yield a nonzero result. `--select` is for
diagnostics and can never set `milestone_pass=true`.

See the [fresh detached-clone report](../reports/cache-uvm-2026-11-10/SUMMARY.md)
for measured counts, raw evidence, versions, source/input hashes and waveforms.
