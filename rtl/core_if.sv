`ifndef CORE_IF_SV
`define CORE_IF_SV

`timescale 1ns/1ps

// OBI-style core <-> L1 interface: req/gnt address phase, rvalid response phase.
// One outstanding request (the cache is blocking).
interface core_if (input logic clk, input logic rst_n);
  import cache_pkg::*;

  logic  req;
  logic  gnt;
  addr_t addr;
  logic  we;
  strb_t be;
  data_t wdata;

  logic  rvalid;
  data_t rdata;

  // Separate clocking blocks for the active master and the passive monitor.
  // The monitor samples with #1step so it always sees pre-edge values.
  clocking mst_cb @(posedge clk);
    default input #1step output #1;
    output req, addr, we, be, wdata;
    input  gnt, rvalid, rdata;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input req, gnt, addr, we, be, wdata, rvalid, rdata;
  endclocking

  modport dut (input  clk, rst_n, req, addr, we, be, wdata,
               output gnt, rvalid, rdata);

  modport mst (clocking mst_cb, input clk, rst_n);
  modport mon (clocking mon_cb, input clk, rst_n);

endinterface

`endif
