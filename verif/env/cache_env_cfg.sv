`ifndef CACHE_ENV_CFG_SV
`define CACHE_ENV_CFG_SV

// Single object carrying everything the environment needs to build: per-agent
// configuration, the shared memory model and all virtual interfaces.
class cache_env_cfg extends uvm_object;

  core_agent_cfg core_cfg [NUM_CORES];
  axil_agent_cfg axil_cfg;
  mem_model      mem;

  virtual bus_if         bus_vif;
  virtual cache_probe_if probe_vif [NUM_CORES];

  bit coverage_en   = 1;
  bit scoreboard_en = 1;

  `uvm_object_utils(cache_env_cfg)

  function new(string name = "cache_env_cfg");
    super.new(name);
  endfunction

endclass

`endif
