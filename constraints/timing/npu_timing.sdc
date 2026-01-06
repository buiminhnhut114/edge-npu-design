# Timing Constraints for EdgeNPU
# Target: 500MHz (2ns period)

# Clock definition
create_clock -name clk -period 2.0 [get_ports clk]

# Clock uncertainty
set_clock_uncertainty -setup 0.1 [get_clocks clk]
set_clock_uncertainty -hold 0.05 [get_clocks clk]

# Input delays (AXI interface)
set_input_delay -clock clk -max 0.5 [get_ports s_axil_*]
set_input_delay -clock clk -min 0.1 [get_ports s_axil_*]
set_input_delay -clock clk -max 0.5 [get_ports m_axi_*ready]
set_input_delay -clock clk -min 0.1 [get_ports m_axi_*ready]
set_input_delay -clock clk -max 0.5 [get_ports m_axi_r*]
set_input_delay -clock clk -min 0.1 [get_ports m_axi_r*]
set_input_delay -clock clk -max 0.5 [get_ports m_axi_b*]
set_input_delay -clock clk -min 0.1 [get_ports m_axi_b*]

# Output delays (AXI interface)
set_output_delay -clock clk -max 0.5 [get_ports s_axil_*]
set_output_delay -clock clk -min 0.1 [get_ports s_axil_*]
set_output_delay -clock clk -max 0.5 [get_ports m_axi_aw*]
set_output_delay -clock clk -min 0.1 [get_ports m_axi_aw*]
set_output_delay -clock clk -max 0.5 [get_ports m_axi_w*]
set_output_delay -clock clk -min 0.1 [get_ports m_axi_w*]
set_output_delay -clock clk -max 0.5 [get_ports m_axi_ar*]
set_output_delay -clock clk -min 0.1 [get_ports m_axi_ar*]
set_output_delay -clock clk -max 0.5 [get_ports irq]
set_output_delay -clock clk -min 0.1 [get_ports irq]

# Reset - async, but needs synchronizer
set_false_path -from [get_ports rst_n]

# Multi-cycle paths for accumulator
# (accumulator results are not needed every cycle)
# set_multicycle_path -setup 2 -from [get_cells */u_pe_array/*/accumulator*]
# set_multicycle_path -hold 1 -from [get_cells */u_pe_array/*/accumulator*]

# Max delay for critical paths in PE array
set_max_delay 1.5 -from [get_cells */u_pe_array/*/weight_reg*] -to [get_cells */u_pe_array/*/accumulator*]
