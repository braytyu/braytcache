`ifndef AXIL_AGENT_SV
`define AXIL_AGENT_SV

class axil_agent extends uvm_agent;

  axil_agent_cfg    cfg;
  axil_slave_driver drv;
  axil_monitor      mon;

  uvm_analysis_port #(axil_item) ap;

  `uvm_component_utils(axil_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(axil_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("AXIL_AGENT", "axil_agent_cfg not found in config_db")

    mon = axil_monitor::type_id::create("mon", this);
    if (cfg.is_active == UVM_ACTIVE)
      drv = axil_slave_driver::type_id::create("drv", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.cfg = cfg;
    mon.vif = cfg.vif;
    mon.ap.connect(ap);
    if (cfg.is_active == UVM_ACTIVE) begin
      drv.cfg = cfg;
      drv.vif = cfg.vif;
    end
  endfunction

endclass

`endif
