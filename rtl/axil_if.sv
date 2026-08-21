`ifndef AXIL_IF_SV
`define AXIL_IF_SV

`timescale 1ns/1ps

// Standard AXI4-Lite: five independent channels, single beat per transaction.
// The interconnect is the master; the memory model is driven by a UVM slave
// agent through slv_cb.
interface axil_if (input logic clk, input logic rst_n);
  import cache_pkg::*;

  logic       awvalid, awready;
  addr_t      awaddr;
  logic [2:0] awprot;

  logic       wvalid, wready;
  data_t      wdata;
  strb_t      wstrb;

  logic       bvalid, bready;
  logic [1:0] bresp;

  logic       arvalid, arready;
  addr_t      araddr;
  logic [2:0] arprot;

  logic       rvalid, rready;
  data_t      rdata;
  logic [1:0] rresp;

  modport mst (input  clk, rst_n,
               output awvalid, awaddr, awprot, wvalid, wdata, wstrb, bready,
                      arvalid, araddr, arprot, rready,
               input  awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp);

  clocking slv_cb @(posedge clk);
    default input #1step output #1;
    input  awvalid, awaddr, awprot, wvalid, wdata, wstrb, bready,
           arvalid, araddr, arprot, rready;
    output awready, wready, bvalid, bresp, arready, rvalid, rdata, rresp;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step;
    input awvalid, awready, awaddr, awprot,
          wvalid, wready, wdata, wstrb,
          bvalid, bready, bresp,
          arvalid, arready, araddr, arprot,
          rvalid, rready, rdata, rresp;
  endclocking

  modport slv (clocking slv_cb, input clk, rst_n);
  modport mon (clocking mon_cb, input clk, rst_n);

endinterface

`endif
