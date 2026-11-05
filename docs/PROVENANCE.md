# Source and attribution

The DUT RTL is fetched from the following public repositories at exact
commits by `scripts/run_amba.ps1` and compiled in isolated output folders:

| DUT | Source revision |
| --- | --- |
| [APB-Interface-Verification](https://github.com/M-Roohan-Khan-28/APB-Interface-Verification) | `118deb0b339b1c7b000198b7133a05367eb61f76` |
| [AHB-Lite-RAM-Interface](https://github.com/M-Roohan-Khan-28/AHB-Lite-RAM-Interface) | `37a8e976897f53648dbfdd50b9dfe1ccdcb226bb` |
| [AXI4-Lite-Memory-Interface](https://github.com/M-Roohan-Khan-28/AXI4-Lite-Memory-Interface) | `a7b9540f225282e1ffbddf84531e6e5a34e73a86` |
| [AXI4-DMA-Subsystem](https://github.com/M-Roohan-Khan-28/AXI4-DMA-Subsystem) | `7035f579ce8d19d5f06e51b4400789abdf5c22a7` (RTL tested at ancestor `670cb280d5ec4b26cf436f10fe5a5be22abb5c90`; later merge adds evidence only) |

The first two DUT repositories preserve their original `hdl-labs` source
and historical logs; the AXI4-Lite repository preserves its extracted SoC
files; the DMA repository preserves the jointly developed MIT baseline and
its notices. This repository adds separate checkers, adapters, tests and
runners; it does not vendor or change those original DUT files. The
`scripts/run_portfolio_regression.ps1` entry point and inventory were copied
from the local portfolio launch kit after its nine-suite milestone passed.

The user confirmed joint development with Talib and permission to reuse and
enhance the reference projects. That context does not change individual
source licences or notices.
