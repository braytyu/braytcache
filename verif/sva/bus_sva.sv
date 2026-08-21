`ifndef BUS_SVA_SV
`define BUS_SVA_SV

`timescale 1ns/1ps

module bus_sva import cache_pkg::*; (
  input logic clk,
  input logic rst_n,
  bus_if      bus
);

  // Flatten the per-core unpacked arrays into vectors so the properties can use
  // $onehot0 and bitwise masks directly.
  logic [NUM_CORES-1:0] req_v, gnt_v, rsp_v, sel_v, ack_v, hit_v, pd_v;

  always_comb begin
    for (int unsigned i = 0; i < NUM_CORES; i++) begin
      req_v[i] = bus.req[i];
      gnt_v[i] = bus.gnt[i];
      rsp_v[i] = bus.rsp_valid[i];
      sel_v[i] = bus.snoop_sel[i];
      ack_v[i] = bus.snoop_ack[i];
      hit_v[i] = bus.snoop_hit[i];
      pd_v[i]  = bus.snoop_pass_dirty[i];
    end
  end

  default clocking sva_cb @(posedge clk); endclocking
  default disable iff (!rst_n);

  // --- exclusive ownership ------------------------------------------------

  a_gnt_onehot0: assert property ($onehot0(gnt_v));
  a_rsp_onehot0: assert property ($onehot0(rsp_v));

  a_rsp_implies_gnt: assert property (
    rsp_v != '0 |-> rsp_v == gnt_v);

  // Ownership never transfers without passing through an idle cycle.
  a_gnt_stable: assert property (
    gnt_v != '0 |=> $stable(gnt_v) || gnt_v == '0);

  // --- snoop well-formedness ----------------------------------------------

  a_snoop_excludes_owner: assert property (
    (gnt_v & sel_v) == '0);

  a_snoop_during_txn: assert property (
    bus.snoop_valid |-> gnt_v != '0);

  a_snoop_not_writeback: assert property (
    bus.snoop_valid |-> bus.snoop_op != BUS_WRITEBACK);

  a_ack_qualified: assert property (
    (ack_v & ~sel_v) == '0);

  // At most one cache may hold a line dirty, so at most one may supply it.
  a_single_pass_dirty: assert property (
    $onehot0(pd_v & sel_v & ack_v));

endmodule

`endif
