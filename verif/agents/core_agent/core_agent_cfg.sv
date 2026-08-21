`ifndef CORE_AGENT_CFG_SV
`define CORE_AGENT_CFG_SV

class core_agent_cfg extends uvm_object;

  virtual core_if          vif;
  uvm_active_passive_enum  is_active = UVM_ACTIVE;
  int unsigned             core_id   = 0;
  bit                      coverage_en = 1;

  `uvm_object_utils(core_agent_cfg)

  function new(string name = "core_agent_cfg");
    super.new(name);
  endfunction

endclass

`endif
