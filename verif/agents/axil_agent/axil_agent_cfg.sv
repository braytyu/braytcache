`ifndef AXIL_AGENT_CFG_SV
`define AXIL_AGENT_CFG_SV

class axil_agent_cfg extends uvm_object;

  virtual axil_if         vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  mem_model               mem;

  rand int unsigned min_delay;
  rand int unsigned max_delay;

  // Randomised per test. Varying memory latency shifts the timing between line
  // fills and coherence traffic, so the same seed exercises different overlaps.
  constraint c_delay {
    min_delay <= max_delay;
    soft min_delay inside {[0:2]};
    soft max_delay inside {[0:6]};
  }

  `uvm_object_utils(axil_agent_cfg)

  function new(string name = "axil_agent_cfg");
    super.new(name);
    min_delay = 0;
    max_delay = 3;
  endfunction

  function int unsigned rand_delay();
    return $urandom_range(max_delay, min_delay);
  endfunction

endclass

`endif
