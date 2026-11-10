# Deterministic VGA UVM/SVA contract and scheduling

This separate milestone uses VGA-SRAM-Framebuffer source lock
`8e257d11b1964fe82d4d4f3c3192b6a315d3b93d`. Earlier releases, inventories, runners, locks and reports remain
unchanged. The source's RGB background and DIL artwork are preserved.

The implementation has an internal 80 by 60 RGB332 framebuffer and a 13-bit
write address. Each enabled rising input-clock edge writes addresses 0..4799;
4800..8191 are ignored. Writes remain enabled during asynchronous active-high
raster reset; framebuffer contents survive reset. Reset initializes the raster
and divider to zero, so active RGB can remain nonblack at framebuffer location 0.
There is no write handshake, external SRAM interface or update atomicity.

The independent raster advances one position per four input clocks, h=0..799,
v=0..524. Active is h<640 and v<480. Active-low HSYNC is h=656..751 and VSYNC
v=490..491. RGB is zero during blanking. Expected framebuffer address is
`(v/8)*80 + h/8`. Expected RGB is computed arithmetically from RGB332, separately
from the RTL concatenations. The framebuffer model initializes from the stated
three-band/DIL image specification, then accepts only public clock-edge writes.
Neither model reads private RTL state or resynchronizes to observed sync pins.

## Scheduling fixed before qualification

Input-clock period is **10 ns** in simulation. The clock runs continuously.
Ordinary controls change atomically 2 ns after a falling edge. The passive
monitor coalesces coincident delta-cycle inputs at +1 ps, captures accepted
write controls, then observes output pins at +1 ns. It publishes a packed typed
observation, without allocating a heavy object or printing on each clock.
Reference framebuffer updates occur only for rising-clock observations.
Control/reset changes between clocks create observations without writes or
raster advances. Falling clocks alone create no comparison observation.

The separate raster and memory models export expected pins to concurrent
assertions on an event 1 ps after publishing the settled expectations. This
separate time slot gives Preponed assertion sampling the current expectations;
the actual pin observation remains at +1 ns. Assertion diagnostics execute
before the scoreboard verdict 10 ps later. Reset-specific checking includes
retained RGB and writes during reset; it is never disabled with disable-iff.
No unconditional four-clock RGB stability rule exists. Current-entry writes
may change RGB on any rising clock even without a raster advance.

The concurrent assertions have no history operators. Their complete expected /
observed signature is evaluated initially, whenever that signature changes,
on every control/reset observation and on every enabled write clock. Omitting
duplicate constant signatures preserves the truth of these pure predicates;
the scoreboard still checks every rising edge and input-control observation.
Assertion samples and functional observations are recorded separately. No
actual mismatch or changed expectation can be skipped by this predicate.

The between-clock pending-write reset is asserted 3.5 ns after a falling edge,
after the pending-control observation has completed. The coincident-reset test
uses a nonblocking reset update at the write edge; write inputs were established
before that edge, and monitor capture follows NBA settlement. These intervals
are harness scheduling assumptions, not hardware timing guarantees.

## Requirements to tests and checkers

| Requirement | Named execution / checker |
| --- | --- |
| Initial artwork/signature, two consecutive frames | initial_image through consecutive_second_frame; full independent RGB/timing oracle; actual full-frame pixel stream |
| Active/blank/sync boundaries, line/frame wrap | horizontal_boundaries, line_wrap, vertical_active_boundary, vertical_sync_boundaries, frame_wrap; HSYNC/VSYNC/ACTIVE/BLANK assertions |
| All framebuffer entries; high-address alias resistance | pattern_low/high_load and scans; low eight address bits plus a second pattern encoding high five bits; distinct-address accounting |
| Invalid writes before masking overwrites | invalid_low/high_sideeffects followed immediately by complete scans, without intervening valid writes |
| All 256 RGB values | all_rgb332 and scanned patterns; arithmetic RGB oracle / RGB assertion |
| 8 by 8 replication and first/last/row entries | every public sample of both complete pattern scans; addresses 0,79,80,4799 explicitly written |
| Back-to-back / held enabled writes | back_to_back_edges, held_enable; per-clock intended/observed enable/address/data and valid/ignored accounting |
| Inactive input freedom | inactive_input_changes; observation without modeled storage update |
| Every divider phase, advancing/nonadvancing current writes | divider_phase_writes; pre-edge phase counters, current_previous_future |
| Active / blank writes with subsequent visibility | current_previous_future, horizontal_blanking_write, vertical_blanking_write_and_sync_reset |
| Asynchronous reset, clock writes under reset, retention | active_reset, hsync_reset, asynchronous_pending_write, held_reset_writes, coincident_reset_write, repeated_reset_retention |
| Release first four clocks and recovery | release_first_four_clocks, post_reset_operation |
| Assertion execution and legal exceptions | six isolated negatives and four legal synthetic controls; separate from real-DUT raster execution |
| Oracle/failure reliability | disposable fault children and actual production-predicate synthetic runner fixtures |

Intended controls are recorded independently by the driver before actual drive.
They travel on a separate UVM analysis port and are retained in `intents.csv`;
the passive monitor reconstructs actual public input wires. Enabled clock-edge
observations are retained in `accepted-writes.csv`. A separate Python interval
model derives every intended rising-edge write from the drive windows and
reconciles the entire accepted-record sequence, including held enables,
invalid addresses and coincident reset. This audit checks timestamps, address,
data, validity and reset classification, not only aggregate counts.
The passive oracle compares the complete observed input window with that intent,
then models public accepted writes. Held enable permits one write per clock.
These are public write attempts/contract commits; an idempotent internal write
has no distinguishable external effect and no detection claim is made for it.

Complete reset-aligned lines/frames are counted independently of partial reset
intervals. Input clocks, advances, once-per-pixel samples, active samples, write
attempts, and six-pin-group comparisons are separate measurements, not coverage.

The required measured-evidence substep renders five bounded public-pin VCD
windows and one **simulation-reconstructed frame** from the actual recorded
R4/G4/B4/HS/VS/active bytes. It samples the first rising clock per raster pixel
(post-divider phase 1), at the same +1 ns output observation. Display channels
are each multiplied by 17 to map 4-bit values to 8-bit image channels. Scalar
public VCD bits are grouped for readable bus displays without rewriting the
capture. Metadata records every source hash, test, window and grouping.
The original DIL initialization is additionally checked by a specification
checksum against RGB332 bytes decoded from actual cell-origin pixels. Expected
bytes do not supply the measured image. Missing/invalid evidence fails the runner.

## Qualification policy and limits

Synthetic controls exercise the exact concurrent assertion module with legal or
injected output samples. Fault runs use disposable RTL copies or a labelled
driver shim with the production reference/scoreboard/assertion path. A parent
requires one exact UVM fatal (or the intentional missing-marker condition), the
exact assertion-identifier set listed in inventory, and child wrapper exit 1.
All three tools must exit 0 without timeout; unrelated errors cannot qualify.
Matching input hashes, nonce, mutation identity and clean locked source are
mandatory. Passing controls remain separately executed.

Functional coverage, constrained randomization and original licence-blocked
advanced ALU/APB environments remain **NOT RUN**. External SRAM, board/display
compatibility, physical pixel/refresh frequency, new resolutions, double
buffering, coverage closure, synthesis, timing, FPGA and hardware are separate.
