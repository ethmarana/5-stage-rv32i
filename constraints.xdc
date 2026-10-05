# 125 mhz base clock
create_clock -name cpu_clk -period 8.000 [get_ports clk]

# out of context timing
set_property HD.CLK_SRC BUFGCTRL_X0Y16 [get_ports clk]