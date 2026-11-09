# Measured corrective waveforms

These are measured public-pin captures, not expected diagrams. Each SVG caption
and JSON metadata identifies the exact original VCD SHA-256 and tick range.
Original capture bytes are committed under `-text`, without conversion.

- [Tail 1, held inactive-lane transform](waveforms/inactive_tail_1.svg)
- [Tail 7, held inactive-lane transform](waveforms/inactive_tail_7.svg)
- [Busy SLVERR followed by protected-state readbacks](waveforms/busy_rejections.svg)

The renderer checks actual pre-edge handshake/state values before selecting
these windows. Simulation scoreboards decide correctness; figures are evidence
of the measured selected events, not coverage closure.
