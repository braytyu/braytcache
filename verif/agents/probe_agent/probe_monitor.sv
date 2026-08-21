`ifndef PROBE_MONITOR_SV
`define PROBE_MONITOR_SV

// Whitebox monitor over one cache's tag/state arrays. Emits one item per
// observed line-state change, which is what MESI transition coverage and the
// eviction checks are built on.
class probe_monitor extends uvm_monitor;

  virtual cache_probe_if vif;
  int unsigned           core_id;

  uvm_analysis_port #(probe_item) ap;

  protected mesi_e prev_state [NUM_SETS][NUM_WAYS];
  protected tag_t  prev_tag   [NUM_SETS][NUM_WAYS];

  `uvm_component_utils(probe_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  protected function void snapshot_reset();
    for (int unsigned s = 0; s < NUM_SETS; s++) begin
      for (int unsigned w = 0; w < NUM_WAYS; w++) begin
        prev_state[s][w] = MESI_I;
        prev_tag[s][w]   = '0;
      end
    end
  endfunction

  // Full sweep of the tag and state arrays every cycle, emitting an item for
  // any way whose state or tag moved. This is the raw event stream that MESI
  // transition coverage and the allocation checks are built on.
  task run_phase(uvm_phase phase);
    probe_item it;

    snapshot_reset();

    forever begin
      @(posedge vif.clk);

      if (vif.rst_n !== 1'b1) begin
        snapshot_reset();
        continue;
      end

      for (int unsigned s = 0; s < NUM_SETS; s++) begin
        for (int unsigned w = 0; w < NUM_WAYS; w++) begin
          if (vif.state[s][w] !== prev_state[s][w] || vif.tag[s][w] !== prev_tag[s][w]) begin
            it           = probe_item::type_id::create("it");
            it.core_id   = core_id;
            it.set_idx   = s;
            it.way_idx   = w;
            it.old_state = prev_state[s][w];
            it.new_state = vif.state[s][w];
            it.old_tag   = prev_tag[s][w];
            it.new_tag   = vif.tag[s][w];
            it.new_data  = vif.data[s][w];
            it.t         = $time;
            ap.write(it);

            prev_state[s][w] = vif.state[s][w];
            prev_tag[s][w]   = vif.tag[s][w];
          end
        end
      end
    end
  endtask

endclass

`endif
