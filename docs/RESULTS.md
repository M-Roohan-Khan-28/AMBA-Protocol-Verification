# Results

Committed-source, publication and clean-clone results will be recorded after
their actual runs. Development runs are not a substitute for those gates.

ModelSim Intel FPGA Starter Edition 2020.1 compiled the four adapter groups
in local development. APB, AHB-Lite, AXI4-Lite and DMA adapter simulations
reached their PASS markers, and each corresponding injected-violation test
detected its fault. These runs used an uncommitted local tree; their logs
are local under `build/test-runs/amba-*-dev*-2026-11-06/`. The first APB
adapter run failed because its expected monitor count ignored reset; that
test expectation was corrected. The first AXI4 bind attempt was not
elaborated by ModelSim and was replaced with a separate wrapper adapter.
No result here is claimed as functional coverage or protocol compliance.
