`ifndef AXIL_SVA_SV
`define AXIL_SVA_SV

`timescale 1ns/1ps

module axil_sva import cache_pkg::*; (
  input logic clk,
  input logic rst_n,
  axil_if     axi
);

  default clocking sva_cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // --- channel stability: payload must not move while valid waits for ready

  a_aw_stable: assert property (
    axi.awvalid && !axi.awready |=> axi.awvalid && $stable(axi.awaddr) && $stable(axi.awprot));

  a_w_stable: assert property (
    axi.wvalid && !axi.wready |=> axi.wvalid && $stable(axi.wdata) && $stable(axi.wstrb));

  a_ar_stable: assert property (
    axi.arvalid && !axi.arready |=> axi.arvalid && $stable(axi.araddr) && $stable(axi.arprot));

  a_b_stable: assert property (
    axi.bvalid && !axi.bready |=> axi.bvalid && $stable(axi.bresp));

  a_r_stable: assert property (
    axi.rvalid && !axi.rready |=> axi.rvalid && $stable(axi.rdata) && $stable(axi.rresp));

  // --- responses and addressing -------------------------------------------

  a_bresp_okay: assert property (axi.bvalid |-> axi.bresp == AXI_OKAY);
  a_rresp_okay: assert property (axi.rvalid |-> axi.rresp == AXI_OKAY);

  a_aw_aligned: assert property (
    axi.awvalid |-> axi.awaddr[BYTE_OFF_W-1:0] == '0);
  a_ar_aligned: assert property (
    axi.arvalid |-> axi.araddr[BYTE_OFF_W-1:0] == '0);

  // --- channel ordering: count handshakes so a response cannot precede its
  // own address/data phase.

  int aw_cnt, w_cnt, b_cnt, ar_cnt, r_cnt;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      aw_cnt <= 0; w_cnt <= 0; b_cnt <= 0; ar_cnt <= 0; r_cnt <= 0;
    end else begin
      if (axi.awvalid && axi.awready) aw_cnt <= aw_cnt + 1;
      if (axi.wvalid  && axi.wready)  w_cnt  <= w_cnt  + 1;
      if (axi.bvalid  && axi.bready)  b_cnt  <= b_cnt  + 1;
      if (axi.arvalid && axi.arready) ar_cnt <= ar_cnt + 1;
      if (axi.rvalid  && axi.rready)  r_cnt  <= r_cnt  + 1;
    end
  end

  a_b_needs_aw_and_w: assert property (
    axi.bvalid |-> (aw_cnt > b_cnt) && (w_cnt > b_cnt));

  a_r_needs_ar: assert property (
    axi.rvalid |-> ar_cnt > r_cnt);

endmodule

`endif
