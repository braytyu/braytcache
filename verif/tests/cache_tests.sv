`ifndef CACHE_TESTS_SV
`define CACHE_TESTS_SV

// Builds the environment, distributes virtual interfaces, and runs whichever
// virtual sequence the derived test selects. Every test differs only in
// create_vseq(), so the build and objection handling live in one place.
class cache_base_test extends uvm_test;

  cache_env     env;
  cache_env_cfg cfg;

  protected int unsigned txn_override;
  protected int unsigned default_txns;

  `uvm_component_utils(cache_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!$value$plusargs("num_txns=%d", txn_override)) txn_override = 0;

    cfg     = cache_env_cfg::type_id::create("cfg");
    cfg.mem = mem_model::type_id::create("mem");

    for (int unsigned i = 0; i < NUM_CORES; i++) begin
      cfg.core_cfg[i]           = core_agent_cfg::type_id::create($sformatf("core_cfg%0d", i));
      cfg.core_cfg[i].core_id   = i;
      cfg.core_cfg[i].is_active = UVM_ACTIVE;

      if (!uvm_config_db #(virtual core_if)::get(this, "",
            $sformatf("core_vif%0d", i), cfg.core_cfg[i].vif))
        `uvm_fatal("TEST", $sformatf("core_vif%0d not set", i))

      if (!uvm_config_db #(virtual cache_probe_if)::get(this, "",
            $sformatf("probe_vif%0d", i), cfg.probe_vif[i]))
        `uvm_fatal("TEST", $sformatf("probe_vif%0d not set", i))
    end

    cfg.axil_cfg     = axil_agent_cfg::type_id::create("axil_cfg");
    cfg.axil_cfg.mem = cfg.mem;
    if (!cfg.axil_cfg.randomize())
      `uvm_error("TEST", "axil_agent_cfg randomize failed")

    if (!uvm_config_db #(virtual axil_if)::get(this, "", "mem_vif", cfg.axil_cfg.vif))
      `uvm_fatal("TEST", "mem_vif not set")
    if (!uvm_config_db #(virtual bus_if)::get(this, "", "bus_vif", cfg.bus_vif))
      `uvm_fatal("TEST", "bus_vif not set")

    uvm_config_db #(cache_env_cfg)::set(this, "env", "cfg", cfg);
    env = cache_env::type_id::create("env", this);

    uvm_top.set_timeout(2ms, 1);
  endfunction

  function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    `uvm_info("CFG", $sformatf(
      "cores=%0d sets=%0d ways=%0d line=%0dB  mem_delay=[%0d:%0d]",
      NUM_CORES, NUM_SETS, NUM_WAYS, LINE_BYTES,
      cfg.axil_cfg.min_delay, cfg.axil_cfg.max_delay), UVM_LOW)
  endfunction

  // Overridden by each test to select its stimulus.
  virtual function cache_base_vseq create_vseq();
    return random_vseq::type_id::create("vseq");
  endfunction

  task run_phase(uvm_phase phase);
    cache_base_vseq vseq;
    int unsigned    n;

    phase.raise_objection(this, get_type_name());

    vseq = create_vseq();
    // +num_txns overrides everything, then any per-test default, otherwise the
    // sequence randomises its own length.
    n    = (txn_override > 0) ? txn_override : default_txns;

    if (n > 0) begin
      if (!vseq.randomize() with { num_txns == n; })
        `uvm_error("TEST", "vseq randomize failed")
    end else begin
      if (!vseq.randomize())
        `uvm_error("TEST", "vseq randomize failed")
    end

    vseq.start(env.vsqr);

    // Drain so in-flight bus traffic settles before check_phase inspects the
    // caches and memory.
    repeat (100) @(posedge cfg.bus_vif.clk);
    phase.drop_objection(this, get_type_name());
  endtask

endclass


class smoke_test extends cache_base_test;
  `uvm_component_utils(smoke_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    default_txns = 15;
  endfunction
endclass


class random_test extends cache_base_test;
  `uvm_component_utils(random_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass


class shared_region_test extends cache_base_test;
  `uvm_component_utils(shared_region_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return shared_region_vseq::type_id::create("vseq");
  endfunction
endclass


class false_sharing_test extends cache_base_test;
  `uvm_component_utils(false_sharing_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return false_sharing_vseq::type_id::create("vseq");
  endfunction
endclass


class pingpong_test extends cache_base_test;
  `uvm_component_utils(pingpong_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return pingpong_vseq::type_id::create("vseq");
  endfunction
endclass


class eviction_test extends cache_base_test;
  `uvm_component_utils(eviction_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return eviction_vseq::type_id::create("vseq");
  endfunction
endclass


class read_mostly_test extends cache_base_test;
  `uvm_component_utils(read_mostly_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return read_mostly_vseq::type_id::create("vseq");
  endfunction
endclass


class store_streak_test extends cache_base_test;
  `uvm_component_utils(store_streak_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return store_streak_vseq::type_id::create("vseq");
  endfunction
endclass


class producer_consumer_test extends cache_base_test;
  `uvm_component_utils(producer_consumer_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return producer_consumer_vseq::type_id::create("vseq");
  endfunction
endclass


// Directed. Closes cg_mesi by construction rather than by seed.
class mesi_walk_test extends cache_base_test;
  `uvm_component_utils(mesi_walk_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return mesi_walk_vseq::type_id::create("vseq");
  endfunction
endclass


// Directed. Targets the CleanUnique -> ReadUnique degradation race.
class upgrade_race_test extends cache_base_test;
  `uvm_component_utils(upgrade_race_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return upgrade_race_vseq::type_id::create("vseq");
  endfunction
endclass


// Chains several stimulus phases in one seed; this is the regression workhorse.
class regression_test extends cache_base_test;
  `uvm_component_utils(regression_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function cache_base_vseq create_vseq();
    return mixed_vseq::type_id::create("vseq");
  endfunction
endclass

`endif
