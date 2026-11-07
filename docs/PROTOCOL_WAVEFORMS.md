# Measured AMBA protocol traces

**Byte provenance for the figures below:** The six SVGs were rendered from
original CRLF simulator captures. Their adjacent JSON now labels
`capture_source_sha256` as the capture hash and `source_sha256` as the hash of
the committed LF Git VCD. The [portfolio waveform byte audit](../reports/technical-release-2026-11-08/waveform-byte-audit.json)
maps both byte representations across all eleven technical repositories and
verifies the Git blobs against public raw downloads. Newline conversion does
not change simulation behavior or VCD events.

These six figures were rendered from four actual ModelSim VCD captures at
AMBA test source `1f0d5491cd084a95c5137ad7072a621ea059b2e3`, with a
clean worktree. The pinned APB, AHB, AXI4-Lite and DMA sources were cloned by
`scripts/run_amba.ps1`. The internal suite passed 11/11 simulations, exit 0,
before capture. Each capture reran an existing compiled test top, reached its
required marker and `$finish`, reported zero simulator errors/warnings, and
returned process exit 0. ModelSim Intel FPGA Starter Edition reported
`vsim 2020.1 Simulator 2020.02 Feb 28 2020`.

| Captured test top | Measured figure and 1 ps VCD tick window | Property illustrated |
| --- | --- | --- |
| `apb_responder_test` | [Two-cycle wait](../reports/technical-completion-2026-11-08/protocol-waves/apb-wait.svg), 30000–155000; [error address](../reports/technical-completion-2026-11-08/protocol-waves/apb-error.svg), 320000–390000 | `select`, `enable`, stable address/control, `ready` and `error` |
| `ahb_adapter_test` | [Write address/data phases](../reports/technical-completion-2026-11-08/protocol-waves/ahb-write-phases.svg), 520000–580000; [two-cycle ERROR](../reports/technical-completion-2026-11-08/protocol-waves/ahb-error.svg), 1460000–1510000 | Accepted address followed by write data; first ERROR cycle holds `HREADYOUT` low, second completes high |
| `axi_lite_response_negative` | [Early B/R under backpressure](../reports/technical-completion-2026-11-08/protocol-waves/axil-response-negative.svg), 0–130000 | **Intentional invalid stimulus**; monitor counts violations while BREADY/RREADY are low and for same-edge dependencies |
| `axi4_response_negative` | [Early B/R and same-edge dependencies](../reports/technical-completion-2026-11-08/protocol-waves/axi4-response-negative.svg), 0–170000 | **Intentional invalid stimulus**; reset-isolated scenarios require individual detection markers |

The [raw VCDs, direct simulator logs, renderer metadata and capture manifest](../reports/technical-completion-2026-11-08/protocol-waves/)
record the exact test top, selected pins, capture command, source revision,
process result, actual time range and VCD SHA-256. The manifest identifies the
compiled work directories produced by `run_amba.ps1`; rerun that script at
the locked source before replaying the recorded `vsim` commands. VCD values
and images illustrate a checked property; the independent test oracles and
monitor detections in the logs determine the simulation result. The renderer
explicitly records `NOT_ASSESSED_BY_RENDERER`.

The [DMA W-before-AW measured trace](https://github.com/M-Roohan-Khan-28/AXI4-DMA-Subsystem/blob/5f7543bf1bf4d5e7638def9d363c106c2e7b55d0/reports/technical-completion-2026-11-07/wave-all_w_before_aw_16/dma-order.svg)
and the [standalone AXI4-Lite legal-channel trace](https://github.com/M-Roohan-Khan-28/AXI4-Lite-Memory-Interface/blob/aa7161ddd194f1d17087e428fa7093e3033d4aaa/reports/technical-completion-2026-11-07/measured-waveform/legal-selected.svg)
come from the other pinned project suites. They remain separate from the
four AMBA captures above. Expected timing diagrams are labelled separately
in project documentation. These bounded traces do not establish complete
APB, AHB-Lite, AXI4-Lite, or AXI4 compliance, timing closure or hardware
behavior.
