# Separate deterministic AXI4 DMA UVM/SVA milestone

This environment verifies the bounded **programmed-command** DMA in
AXI4-DMA-Subsystem. It is separate from the completed eleven-project portable
release and deterministic APB/AXI4-Lite UVM/SVA releases. Their inventories,
runners, source locks and historical reports are unchanged.

## Frozen contract and source

The DUT is pinned by `verification/dma_uvm/sources.json` to
`a2d3d57edaa9eb441f3289bf5320f4df2f074144`. The original MIT notice and joint
M. Roohan Khan/Talib attribution remain in the DUT repository. No vendor UVM
sources are redistributed. The verification baseline is AMBA
`60b2db25bf007b17d530389cb26a71578f5c28f8`.

- One command at a time; 32-bit AXI4-Lite control; 64-bit AXI4 data, ID zero,
  eight-byte INCR beats, 1–16 beats per burst. One complete read burst precedes
  its write burst. AW/W acceptance is independent, including all W before AW.
- Length 0–4096 bytes; nonzero commands require eight-byte aligned,
  nonoverlapping source/destination ranges. Both 4 KiB boundaries limit bursts.
  A final partial write uses low-byte strobes; source reads include unused bytes
  of the last beat, so the source must be ordinary RAM.
- Range arithmetic is unsigned and widened: an end equal to `2^32` is valid;
  one exceeding it is rejected. Zero length bypasses address validation.
- Reset is shared with the modeled target. It cancels pending protocol state,
  clears CSRs/status and does not undo already committed memory writes. Resetting
  the DMA alone is not a cancellation guarantee for an external target.

| CSR byte offset | Read | Accepted full-word writes while idle |
| --- | --- | --- |
| `0x00` | source address | source address |
| `0x04` | destination address | destination address |
| `0x08` | length | length |
| `0x0C` | zero | 0 no-op; 1 start; 2 acknowledge |
| `0x10` | bits 0 busy, 1 done, 2 error, 3 IRQ | read only |
| `0x14` | error code | read only |

All writable registers require `WSTRB=15`. Unknown/misaligned offsets,
read-only writes, other control values, and configuration/control writes while
busy return SLVERR. A rejected control transaction is not an accepted command.
An accepted start can terminate with invalid-request error 1, read error 2 or
write error 3. Done/error/IRQ are sticky; reads do not create new completions.
Idle acknowledge clears status. An accepted start also clears previous status.

**Specification clarification:** `docs/SPECIFICATION.md` in the locked DUT says
read errors consume the rest of the accepted burst. That is accurate for a
normal-length burst carrying an error response or wrong RID. The RTL also stops
on early RLAST, or at its planned final beat even if RLAST is missing. Arbitrary
malformed response streams are not guaranteed to drain. Wrong RID/BID and
early/missing RLAST are separate reset-isolated malformed-target scenarios,
not legal error responses. Recovery uses a shared reset and a subsequently
well-behaved target. No RTL change is implied by this clarification.

## Architecture and independence

`dma_sequence` creates named deterministic programmed-command items.
`dma_control_driver` implements a real UVM control initiator. The separate
`dma_memory_responder` buffers up to 16 early W beats without knowing the
expected destination, and joins accepted AW with buffered W. It handles
AW-first, W-first, simultaneous handshakes and independent channel delays.

The passive monitor samples only public pins through a clocking block with
`input #1step`; active drivers update at falling edges. The scoreboard builds
its command from accepted control traffic, snapshots intended source bytes and
independently plans byte segments. It never reads DMA internal state. A sparse
unsigned 32-bit-address byte model avoids the historical bench's 32 KiB limit.
An address-sensitive deterministic mixing function defines initial bytes;
responder storage and expected byte storage are separate. Every AR/AW attribute,
R/W beat, LAST, strobe and progression is checked. Destination, source, guard
and other protected bytes are compared against the responder's public memory
model after completion/reset. No test reads internal DUT memory.

Command acceptance, terminal outcome, acknowledge, rejected CSR transactions,
reset cancellation, addresses, beats, responses and write commits have separate
counters. Ownership survives bus response processing until terminal/reset;
ten additional observed cycles after terminal detect unsolicited traffic.
The runner independently reconciles result counts against the named inventory.

The target commits at complete accepted AW plus W, before issuing B. Named
write-error cases explicitly select commit or no-commit policy. Reset retains
any committed bytes. Legal AXI error responses, malformed targets, synthetic
checker controls and test-only oracle faults are recorded separately.

## Requirements matrix

| Requirement | Named inventory group | Independent check |
| --- | --- | --- |
| Length and tails | zero, tails 1–7, lengths 8/16/128/129/4096 | snapshots, byte strobes, burst/beat totals |
| Boundary/range rules | source/destination/both splits; exact top end/page; high address; adjacent; rejection cases | widened range arithmetic, every AR/AW address/length |
| CSR semantics | address/data/same-edge ordering; invalid classes; busy rejections | distinct CSR register/status oracle, response codes, unchanged active command |
| Sticky status | sticky_ack_new_start and repeated status reads in every case | one terminal per accepted command, IRQ/code/ack checks |
| Independent AW/W | aw_first, w_first, all_w_before_aw_1/2/16, same_edge_aw_w_1/2/16, awready_waits_wvalid | actual observed ordering and complete buffered write |
| Stalls | independent_stalls and delayed control responses | VALID/payload SVA, every accepted beat |
| Legal errors | first/middle/final read, read after earlier commit, first/later write and no-commit policy | error code, no later command traffic, exact committed bytes |
| Reset | during read, after B, commit before B, partial CSR AW/W | canceled obligations, retained memory, clean subsequent command |
| Malformed target | wrong RID/BID, early/missing RLAST | exactly named assertion plus documented error and reset recovery |
| Protocol assertion qualification | isolated SVA inventory | expected property identity; no unrelated violations |

The exact named cases and mandatory substeps are in
`verification/dma_uvm/inventory.json`; result counts are derived from that file.

## Scope and unexecuted features

This deterministic environment does not call constrained randomization or
instantiate covergroups. **Functional coverage, constrained randomization and
the original advanced ALU/APB environments are NOT RUN** under the previously
measured licence limitation. Procedural counters are not functional coverage.

Archived multichannel DMA, descriptors/scatter-gather, peripheral handshakes,
multiple outstanding/reordered transactions, arbitrary malformed-target recovery,
full AXI compliance, coverage closure, synthesis, timing, FPGA and hardware are
separate milestones. Progress limits belong to the test environment, not AXI.
No new portable eleven-project aggregate is claimed.

## Original executed review milestone (preserved)

The [separate report](../reports/dma-uvm-2026-11-09/SUMMARY.md) records 43/43
required substeps PASS at environment `e93a6fdff85804dab7b5e636e43880e1ba7615ab`: 60 functional scenarios,
30 SVA controls and eight qualified nonzero fault children. The existing DMA
40-case portable suite and 11-file provenance check also passed. No RTL fix was
needed. [Reproduction](../reports/dma-uvm-2026-11-09/REPRODUCE.md) pins the complete
environment SHA and preserves the DUT lock. New evidence is separate from every
previous report. These procedural counts do not measure functional coverage.

## Corrective review milestone — 10 November 2026

[Corrected evidence](../reports/dma-uvm-corrective-2026-11-10/SUMMARY.md)
records **47/47 required PASS** at `e6fbb510aa88b1f5aa8a7cc04926eeefbfb5be4d`, unchanged DUT lock.
There are 68 scenarios in 7 groups,
30 assertion controls and ten fault qualifications. WDATA comparisons select only
the independently expected enabled lanes; exact WSTRB/LAST/stability and memory
checks remain. Seven legal changed-inactive-lane tail controls include held
partial writes. Each rejected CSR write is read back through SRC/DST/LENGTH and
status/error/control before overwrite or reset, including while the responder
is paused and after sticky success/error. Old tests missed two separately
recorded side-effect mutations; the corrected tests reject both. The runner
validates per-case rejection/readback and command/burst/beat relationships.
[Reproduce](../reports/dma-uvm-corrective-2026-11-10/REPRODUCE.md) by normal clone
and explicit detached full-SHA checkout; no feature-branch name is required.
The original report and all NOT RUN/bounded-scope limitations above remain.
