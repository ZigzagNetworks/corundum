# SPDX-License-Identifier: BSD-2-Clause-Views
# ILA for OCS optical-cut fault timing instrumentation.
# Sampled on qsfp_0_rx_clk_int (~322 MHz). Event-driven capture: storage
# qualifier (probe37 = ila_change_detected) fires only when a monitored
# state signal changes, so each stored sample is a cycle-exact snapshot
# at the moment of transition. probe38 carries a 32-bit cycle-counter
# timestamp so inter-event intervals can be reconstructed exactly.

create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0

set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES         {39} \
    CONFIG.C_DATA_DEPTH            {8192} \
    CONFIG.C_TRIGOUT_EN            {false} \
    CONFIG.C_TRIGIN_EN             {false} \
    CONFIG.C_INPUT_PIPE_STAGES     {2} \
    CONFIG.C_ADV_TRIGGER           {true} \
    CONFIG.C_EN_STRG_QUAL          {1} \
    CONFIG.C_PROBE0_WIDTH          {1} \
    CONFIG.C_PROBE1_WIDTH          {1} \
    CONFIG.C_PROBE2_WIDTH          {1} \
    CONFIG.C_PROBE3_WIDTH          {1} \
    CONFIG.C_PROBE4_WIDTH          {1} \
    CONFIG.C_PROBE5_WIDTH          {1} \
    CONFIG.C_PROBE6_WIDTH          {1} \
    CONFIG.C_PROBE7_WIDTH          {1} \
    CONFIG.C_PROBE8_WIDTH          {1} \
    CONFIG.C_PROBE9_WIDTH          {20} \
    CONFIG.C_PROBE10_WIDTH         {20} \
    CONFIG.C_PROBE11_WIDTH         {20} \
    CONFIG.C_PROBE12_WIDTH         {20} \
    CONFIG.C_PROBE13_WIDTH         {20} \
    CONFIG.C_PROBE14_WIDTH         {20} \
    CONFIG.C_PROBE15_WIDTH         {40} \
    CONFIG.C_PROBE16_WIDTH         {20} \
    CONFIG.C_PROBE17_WIDTH         {20} \
    CONFIG.C_PROBE18_WIDTH         {20} \
    CONFIG.C_PROBE19_WIDTH         {100} \
    CONFIG.C_PROBE20_WIDTH         {140} \
    CONFIG.C_PROBE21_WIDTH         {15} \
    CONFIG.C_PROBE22_WIDTH         {6} \
    CONFIG.C_PROBE23_WIDTH         {10} \
    CONFIG.C_PROBE24_WIDTH         {5} \
    CONFIG.C_PROBE25_WIDTH         {3} \
    CONFIG.C_PROBE26_WIDTH         {7} \
    CONFIG.C_PROBE27_WIDTH         {14} \
    CONFIG.C_PROBE28_WIDTH         {12} \
    CONFIG.C_PROBE29_WIDTH         {17} \
    CONFIG.C_PROBE30_WIDTH         {12} \
    CONFIG.C_PROBE31_WIDTH         {56} \
    CONFIG.C_PROBE32_WIDTH         {5} \
    CONFIG.C_PROBE33_WIDTH         {8} \
    CONFIG.C_PROBE34_WIDTH         {6} \
    CONFIG.C_PROBE35_WIDTH         {14} \
    CONFIG.C_PROBE36_WIDTH         {12} \
    CONFIG.C_PROBE37_WIDTH         {1} \
    CONFIG.C_PROBE38_WIDTH         {32} \
] [get_ips ila_0]
