# AMBA internal suite against merged adapter sources

Clean detached GitHub branch source:
`d6f0cc79270fe8776af1b726e3df5ceeff62a00e`.
The adapter source pins are merged main commits APB
`e30fd5242a1e84be92107d6be75652220748a8a7`, AHB
`659fba67ce85a01643cceca2c8d1e67ea3903995`, AXI4-Lite
`faf43379b24a524999eb2c8ad7e100cde35054c3`, and DMA
`a2d3d57edaa9eb441f3289bf5320f4df2f074144`.

The clean-source `run_amba.ps1` wrapper returned **0** with **11/11 internal
simulations PASS**. `internal-merged-pins/results.json` records every source
pin, case count, exit and simulator version; sibling folders contain each
compile and simulation log. ModelSim Intel FPGA Starter Edition reported
`vsim 2020.1 Simulator 2020.02 Feb 28 2020`. Cases are deterministic;
no pseudorandom seed is used. This internal result is separate from the
eleven-project aggregate still to be locked to merged main revisions.

Reproduce in a fresh detached checkout and output directory:

```powershell
git -c core.autocrlf=false clone --branch technical/response-order-qualification https://github.com/M-Roohan-Khan-28/AMBA-Protocol-Verification.git C:\short\amba-source-new
git -C C:\short\amba-source-new config core.autocrlf false
git -C C:\short\amba-source-new checkout --detach d6f0cc79270fe8776af1b726e3df5ceeff62a00e
powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\short\amba-source-new\scripts\run_amba.ps1 -OutputDir C:\short\amba-internal-new
if ($LASTEXITCODE -ne 0) { throw 'AMBA internal suite failed or blocked' }
```
