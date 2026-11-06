# Implemented verification scope

The project tests APB setup/access sequencing and 64-word read/write/reset
behavior; AHB-Lite accepted address and following data phases, word alignment,
size and range errors for a 16-word RAM; AXI4-Lite independent channel
handshakes and byte strobes through a single-request master/slave/SRAM path;
and the bounded 64-bit AXI4 DMA's fixed-ID 1–16-beat INCR bursts and 4 KiB
limits. The selected DUT revisions are pinned in `scripts/run_amba.ps1`.

Monitors are passive and have flat signal ports so adapters can connect a
SystemVerilog interface, a flat DUT, or a hierarchy without placing expected
results in the checker. Negative tests use the same modules without DUTs.
`amba_transactions.sv` defines typed APB, AHB-Lite, and AXI4-Lite requests
and observations. Reusable driver modules issue those requests; adapter
scoreboards decide expected memory data independently. The configurable APB
responder supplies deterministic waits and an error address. The pinned DMA
bench supplies the AXI4 memory responder with deterministic stalls and
selectable read/write errors; it is not copied into this repository.

The APB monitor is for the APB setup/access behavior of the selected DUT and
does not check unimplemented wait-state or error behavior. The AHB-Lite monitor
records qualified address phases and checks controls held during global
`HREADY=0`; it does not certify complete AHB-Lite error-cycle timing. The
AXI4-Lite monitor tracks the five channels and response ordering for one
outstanding request. The AXI4 burst monitor additionally checks the DMA's
fixed ID, beat size, burst type, 4 KiB limits, last beat and supported
write-strobe policy. It is not a general arbitrary-ID AXI4 compliance checker.

These are executable protocol checks and independent functional comparisons,
not measured functional coverage. The original ALU and APB advanced
verification environments require an unavailable `svverification` licence
and are not treated as passing here.
