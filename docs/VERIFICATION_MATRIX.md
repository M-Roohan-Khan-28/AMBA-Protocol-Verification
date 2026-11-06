# Requirements to executable checks

| Interface | Positive adapter and model | Passive monitor | Injected violation |
| --- | --- | --- | --- |
| APB | `apb_adapter_test`: all 64 words, data patterns, readback and reset with a separate 64-word oracle | `apb_monitor`: setup before access, stable address/control/write data, accepted transfer count | `apb_monitor_negative`: access without setup |
| APB responder | `apb_responder_test`: three words of independent readback, two-cycle waits and an error address | The same `apb_monitor`: seven accepted accesses and stable wait phase | The APB negative suite above exercises the same monitor |
| AHB-Lite | `ahb_adapter_test`: all 16 words, address/data phasing, readback, misalignment, size and range errors with a separate 16-word oracle | `ahb_lite_monitor`: qualified address count, stable controls during global stall, response tied to a data phase | `ahb_monitor_negative`: change address during stall |
| AXI4-Lite | `axi_lite_adapter_test`: 8-word SRAM readback, all 16 write-strobe masks and invalid addresses with a separate byte-lane oracle | `axi_lite_monitor`: accepted AW/W/B/AR/R counts, response after request, payload stability under stall | `axi_lite_monitor_negative`: AW address change while stalled |
| AXI4 DMA | `dma_adapter_test`: runs published 25-case independent byte-memory oracle unchanged | `axi4_burst_monitor`: fixed ID/size/INCR, 1–16 beats, page limits, R/W LAST, bounded WSTRB, stall stability and response order | `axi4_monitor_negative`: AW burst crossing 4 KiB |

Each adapter has a finite testbench watchdog, and the PowerShell runner has
a 120-second wall timeout per simulation. Both the simulator log and result
marker must be clean. The negative suites pass only when their expected
violation count is observed; a detector that misses the injected violation
fails the suite.
