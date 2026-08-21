`ifndef CORE_AGENT_SV
`define CORE_AGENT_SV

typedef uvm_sequencer #(core_item) core_sequencer;

class core_agent extends uvm_agent;

  core_agent_cfg cfg;
  core_driver    drv;
  core_sequencer sqr;
  core_monitor   mon;

  uvm_analysis_port #(core_item) ap;

  `uvm_component_utils(core_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  // Driver and sequencer exist only when active; the monitor always runs so a
  // passive build still feeds the scoreboard and coverage.
  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db #(core_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("CORE_AGENT", "core_agent_cfg not found in config_db")

    mon = core_monitor::type_id::create("mon", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      drv = core_driver::type_id::create("drv", this);
      sqr = core_sequencer::type_id::create("sqr", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    mon.cfg = cfg;
    mon.vif = cfg.vif;
    mon.ap.connect(ap);
    if (cfg.is_active == UVM_ACTIVE) begin
      drv.cfg = cfg;
      drv.vif = cfg.vif;
      drv.seq_item_port.connect(sqr.seq_item_export);
    end
  endfunction

endclass

`endif
