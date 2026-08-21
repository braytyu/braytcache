`ifndef AXIL_SLAVE_DRIVER_SV
`define AXIL_SLAVE_DRIVER_SV

class axil_slave_driver extends uvm_driver #(axil_item);

  virtual axil_if vif;
  axil_agent_cfg  cfg;

  `uvm_component_utils(axil_slave_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  task run_phase(uvm_phase phase);
    idle();
    wait (vif.rst_n === 1'b1);
    // Align to a clocking event before the first synchronous drive.
    @(vif.slv_cb);
    fork
      write_channel();
      read_channel();
    join
  endtask

  task idle();
    vif.slv_cb.awready <= 1'b0;
    vif.slv_cb.wready  <= 1'b0;
    vif.slv_cb.bvalid  <= 1'b0;
    vif.slv_cb.bresp   <= AXI_OKAY;
    vif.slv_cb.arready <= 1'b0;
    vif.slv_cb.rvalid  <= 1'b0;
    vif.slv_cb.rdata   <= '0;
    vif.slv_cb.rresp   <= AXI_OKAY;
  endtask

  // AW and W are independent channels, so both are accepted before the write is
  // applied and B is returned. Ready is deasserted after each accept to keep one
  // transaction in flight at a time.
  task write_channel();
    addr_t a;
    data_t d;
    strb_t s;
    bit    got_aw;
    bit    got_w;

    forever begin
      got_aw = 1'b0;
      got_w  = 1'b0;
      vif.slv_cb.bvalid <= 1'b0;

      repeat (cfg.rand_delay()) @(vif.slv_cb);
      vif.slv_cb.awready <= 1'b1;
      vif.slv_cb.wready  <= 1'b1;

      while (!(got_aw && got_w)) begin
        @(vif.slv_cb);
        if (!got_aw && vif.slv_cb.awvalid === 1'b1) begin
          a      = vif.slv_cb.awaddr;
          got_aw = 1'b1;
          vif.slv_cb.awready <= 1'b0;
        end
        if (!got_w && vif.slv_cb.wvalid === 1'b1) begin
          d      = vif.slv_cb.wdata;
          s      = vif.slv_cb.wstrb;
          got_w  = 1'b1;
          vif.slv_cb.wready <= 1'b0;
        end
      end

      repeat (cfg.rand_delay()) @(vif.slv_cb);
      cfg.mem.write(a, d, s);

      vif.slv_cb.bresp  <= AXI_OKAY;
      vif.slv_cb.bvalid <= 1'b1;
      do @(vif.slv_cb); while (vif.slv_cb.bready !== 1'b1);
      vif.slv_cb.bvalid <= 1'b0;
    end
  endtask

  // Address phase, configurable read latency, then data.
  task read_channel();
    addr_t a;

    forever begin
      vif.slv_cb.rvalid <= 1'b0;

      repeat (cfg.rand_delay()) @(vif.slv_cb);
      vif.slv_cb.arready <= 1'b1;
      do @(vif.slv_cb); while (vif.slv_cb.arvalid !== 1'b1);
      a = vif.slv_cb.araddr;
      vif.slv_cb.arready <= 1'b0;

      repeat (cfg.rand_delay()) @(vif.slv_cb);
      vif.slv_cb.rdata  <= cfg.mem.read(a);
      vif.slv_cb.rresp  <= AXI_OKAY;
      vif.slv_cb.rvalid <= 1'b1;
      do @(vif.slv_cb); while (vif.slv_cb.rready !== 1'b1);
      vif.slv_cb.rvalid <= 1'b0;
    end
  endtask

endclass

`endif
