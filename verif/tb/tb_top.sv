`timescale 1ns/1ps

module tb_top;

  import uvm_pkg::*;
  import cache_pkg::*;
  import cache_uvm_pkg::*;

  `include "uvm_macros.svh"

  logic clk;
  logic rst_n;

  // 10 ns clock, reset held for five edges.
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    rst_n = 1'b0;
    repeat (5) @(posedge clk);
    rst_n <= 1'b1;
  end

  // Physical interfaces. The probe interfaces carry no DUT connectivity; they
  // exist purely so the testbench can observe cache state.
  core_if        core_ifs  [NUM_CORES] (.clk(clk), .rst_n(rst_n));
  cache_probe_if probe_ifs [NUM_CORES] (.clk(clk), .rst_n(rst_n));
  bus_if         bus_i                 (.clk(clk), .rst_n(rst_n));
  axil_if        mem_i                 (.clk(clk), .rst_n(rst_n));

  cache_top dut (
    .clk   (clk),
    .rst_n (rst_n),
    .core  (core_ifs),
    .bus   (bus_i),
    .mem   (mem_i)
  );

  // Protocol checkers that only need an interface are instantiated directly;
  // the per-cache checker is attached by bind in sva_bind.sv.
  bus_sva  u_bus_sva  (.clk(clk), .rst_n(rst_n), .bus(bus_i));
  axil_sva u_axil_sva (.clk(clk), .rst_n(rst_n), .axi(mem_i));

  // Whitebox tap on the tag/state arrays. Hierarchical rather than `bind` so
  // that indexing stays elaboration-time constant on every simulator.
  generate
    for (genvar i = 0; i < int'(NUM_CORES); i++) begin : g_probe
      initial probe_ifs[i].core_id = i;

      for (genvar s = 0; s < int'(NUM_SETS); s++) begin : g_set
        assign probe_ifs[i].plru[s] = dut.g_cache[i].u_cache.plru_q[s];
        for (genvar w = 0; w < int'(NUM_WAYS); w++) begin : g_way
          assign probe_ifs[i].state[s][w] = dut.g_cache[i].u_cache.state_q[s][w];
          assign probe_ifs[i].tag[s][w]   = dut.g_cache[i].u_cache.tag_q[s][w];
          assign probe_ifs[i].data[s][w]  = dut.g_cache[i].u_cache.data_q[s][w];
        end
      end
    end
  endgenerate

  // Hand every interface to UVM before the test builds.
  // DECISION: the per-core sets live in a generate block because an interface
  // array can only be indexed by an elaboration-time constant.
  generate
    for (genvar i = 0; i < int'(NUM_CORES); i++) begin : g_vif
      initial begin
        uvm_config_db #(virtual core_if)::set(
          null, "*", $sformatf("core_vif%0d", i), core_ifs[i]);
        uvm_config_db #(virtual cache_probe_if)::set(
          null, "*", $sformatf("probe_vif%0d", i), probe_ifs[i]);
      end
    end
  endgenerate

  initial begin
    uvm_config_db #(virtual bus_if)::set(null, "*", "bus_vif", bus_i);
    uvm_config_db #(virtual axil_if)::set(null, "*", "mem_vif", mem_i);
    // Lets every generate-scoped config_db set above complete first.
    #1;
    run_test();
  end

  initial begin
    if ($test$plusargs("dump")) begin
      $dumpfile("dump.vcd");
      $dumpvars(0, tb_top);
    end
  end

endmodule
