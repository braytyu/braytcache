`ifndef CACHE_PROBE_IF_SV
`define CACHE_PROBE_IF_SV

`timescale 1ns/1ps

// Whitebox observation of one cache's tag/state/data arrays. Driven from
// tb_top by hierarchical continuous assignment; carries no DUT connectivity.
interface cache_probe_if (input logic clk, input logic rst_n);
  import cache_pkg::*;

  int    core_id;
  mesi_e state [NUM_SETS][NUM_WAYS];
  tag_t  tag   [NUM_SETS][NUM_WAYS];
  line_t data  [NUM_SETS][NUM_WAYS];
  plru_t plru  [NUM_SETS];

endinterface

`endif
