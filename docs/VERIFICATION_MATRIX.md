# Requirements to executable checks

| Interface | Positive adapter and model | Passive monitor | Injected violation |
| --- | --- | --- | --- |
| APB | `apb_adapter_test`: all 64 words, data patterns, readback and reset with a separate 64-word oracle | `apb_monitor`: setup before access, stable address/control/write data, accepted transfer count | `apb_monitor_negative`: access without setup |
| APB responder | `apb_responder_test`: three words of independent readback, two-cycle waits and an error address | The same `apb_monitor`: seven accepted accesses and stable wait phase | The APB negative suite above exercises the same monitor |
| AHB-Lite | `ahb_adapter_test`: all 16 words, address/data phasing, readback, misalignment, size and range errors with a separate 16-word oracle, including two-cycle ERROR completion | `ahb_lite_monitor`: qualified address count, stable controls during global stall, response tied to a data phase | `ahb_monitor_negative`: change address during stall |
| AXI4-Lite | `axi_lite_adapter_test`: 8-word SRAM readback, all 16 write-strobe masks and invalid addresses with a separate byte-lane oracle | `axi_lite_monitor`: accepted AW/W/B/AR/R counts, pre-edge response eligibility even under backpressure, payload stability under stall | `axi_lite_monitor_negative`: AW instability; `axi_lite_response_negative`: early B/R held under backpressure and same-edge dependencies |
| AXI4 DMA | `dma_adapter_test`: runs pinned 40-case independent byte-memory oracle with independent AW/W progress | `axi4_burst_monitor`: fixed ID/size/INCR, page limits, R/W LAST, bounded WSTRB, W-before-AW acceptance, pre-edge B/R response eligibility and stall stability | `axi4_monitor_negative`: AW page crossing; `axi4_response_negative`: early B/R held under backpressure and same-edge dependencies |

Each adapter has a finite testbench watchdog, and the PowerShell runner has
a 120-second wall timeout per simulation. Both the simulator log and result
marker must be clean. The negative suites pass only when their expected
violation count is observed; a detector that misses the injected violation
fails the suite.
