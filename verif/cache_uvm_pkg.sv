`ifndef CACHE_UVM_PKG_SV
`define CACHE_UVM_PKG_SV

package cache_uvm_pkg;

  import uvm_pkg::*;
  import cache_pkg::*;

  `include "uvm_macros.svh"

  `include "core_item.sv"
  `include "core_agent_cfg.sv"
  `include "core_driver.sv"
  `include "core_monitor.sv"
  `include "core_agent.sv"
  `include "core_seq_lib.sv"

  `include "mem_model.sv"
  `include "axil_item.sv"
  `include "axil_agent_cfg.sv"
  `include "axil_slave_driver.sv"
  `include "axil_monitor.sv"
  `include "axil_agent.sv"

  `include "bus_item.sv"
  `include "bus_monitor.sv"

  `include "probe_item.sv"
  `include "probe_monitor.sv"

  `include "analysis_imps.sv"
  `include "cache_env_cfg.sv"
  `include "coherence_scoreboard.sv"
  `include "cache_coverage.sv"
  `include "cache_vsequencer.sv"
  `include "cache_env.sv"

  `include "cache_vseq_lib.sv"
  `include "cache_tests.sv"

endpackage

`endif
