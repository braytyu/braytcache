`ifndef CORE_DRIVER_SV
`define CORE_DRIVER_SV

class core_driver extends uvm_driver #(core_item);

  virtual core_if vif;
  core_agent_cfg  cfg;

  `uvm_component_utils(core_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    idle();
    wait (vif.rst_n === 1'b1);
    // Align to a clocking event before the first synchronous drive.
    @(vif.mst_cb);
    forever begin
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  task idle();
    vif.mst_cb.req   <= 1'b0;
    vif.mst_cb.addr  <= '0;
    vif.mst_cb.we    <= 1'b0;
    vif.mst_cb.be    <= '0;
    vif.mst_cb.wdata <= '0;
  endtask

  // OBI: hold the request until gnt, then wait for the rvalid response. Only
  // one request is in flight because the cache is blocking.
  task drive(core_item it);
    it.core_id = cfg.core_id;
    repeat (it.pre_delay) @(vif.mst_cb);

    vif.mst_cb.req   <= 1'b1;
    vif.mst_cb.addr  <= it.addr;
    vif.mst_cb.we    <= (it.op == CORE_STORE);
    vif.mst_cb.be    <= it.be;
    vif.mst_cb.wdata <= it.wdata;
    it.start_time = $time;

    do @(vif.mst_cb); while (vif.mst_cb.gnt !== 1'b1);
    idle();

    do @(vif.mst_cb); while (vif.mst_cb.rvalid !== 1'b1);
    it.rdata    = vif.mst_cb.rdata;
    it.end_time = $time;
  endtask

endclass

`endif
