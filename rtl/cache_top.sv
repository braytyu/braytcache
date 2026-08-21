`ifndef CACHE_TOP_SV
`define CACHE_TOP_SV

`timescale 1ns/1ps

// DUT boundary: N caches sharing one coherent interconnect, with a single
// AXI4-Lite port out to memory.
module cache_top import cache_pkg::*; (
  input logic  clk,
  input logic  rst_n,
  core_if.dut  core [NUM_CORES],
  bus_if       bus,
  axil_if.mst  mem
);

  // Each cache is handed the shared bus interface and drives only its own
  // index of the per-master arrays, so there is a single driver per signal.
  generate
    for (genvar i = 0; i < int'(NUM_CORES); i++) begin : g_cache
      l1_cache #(.CORE_ID(i)) u_cache (
        .clk   (clk),
        .rst_n (rst_n),
        .core  (core[i]),
        .bus   (bus)
      );
    end
  endgenerate

  coherence_bus u_bus (
    .clk   (clk),
    .rst_n (rst_n),
    .bus   (bus),
    .mem   (mem)
  );

endmodule

`endif
