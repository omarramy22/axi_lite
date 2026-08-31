#!/bin/bash
mkdir -p sim
iverilog -g2012 -Irtl -o sim/slave.vvp       rtl/axi_lite_slave.v  rtl/axi_lite_checker.v tb/tb_axi_lite_slave.v  && vvp sim/slave.vvp
iverilog -g2012 -Irtl -o sim/master.vvp      rtl/axi_lite_master.v rtl/axi_lite_checker.v tb/tb_axi_lite_master.v && vvp sim/master.vvp
iverilog -g2012 -Irtl -o sim/integration.vvp rtl/axi_lite_master.v rtl/axi_lite_slave.v rtl/axi_lite_checker.v tb/tb_integration.v && vvp sim/integration.vvp