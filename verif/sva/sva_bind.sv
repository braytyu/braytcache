`ifndef SVA_BIND_SV
`define SVA_BIND_SV

// Attaching the cache assertions by bind keeps them out of the RTL while still
// giving one checker instance per cache automatically. The port expressions are
// elaborated in l1_cache scope, which is why CORE_ID resolves here.
bind l1_cache cache_sva u_cache_sva (
  .clk              (clk),
  .rst_n            (rst_n),
  .core_req         (core.req),
  .core_gnt         (core.gnt),
  .core_rvalid      (core.rvalid),
  .core_addr        (core.addr),
  .core_we          (core.we),
  .core_be          (core.be),
  .core_wdata       (core.wdata),
  .bus_req          (bus.req[CORE_ID]),
  .bus_gnt          (bus.gnt[CORE_ID]),
  .bus_op           (bus.op[CORE_ID]),
  .bus_rsp_valid    (bus.rsp_valid[CORE_ID]),
  .snoop_valid      (bus.snoop_valid),
  .snoop_sel        (bus.snoop_sel[CORE_ID]),
  .snoop_op         (bus.snoop_op),
  .snoop_ack        (bus.snoop_ack[CORE_ID]),
  .snoop_hit        (bus.snoop_hit[CORE_ID]),
  .snoop_pass_dirty (bus.snoop_pass_dirty[CORE_ID])
);

`endif
