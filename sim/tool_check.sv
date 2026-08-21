`timescale 1ns/1ps

// Standalone capability probe. No project dependencies, no UVM.
//
// Run this BEFORE attempting to build braytcache. Each stage exercises exactly
// one language feature the testbench depends on, so whichever stage fails to
// compile tells you precisely which capability your licence is missing.
//
//   cd sim && make check-sv
module tool_check;

  typedef enum logic [1:0] { S_I, S_S, S_E, S_M } st_e;

  logic clk = 1'b0;
  logic req = 1'b0;
  logic gnt = 1'b0;

  always #5 clk = ~clk;

  // --- stage 1: classes, rand, constraints, inline constraints -------------
  class item;
    rand bit [7:0] addr;
    rand bit [3:0] be;
    rand st_e      state;

    constraint c_align { addr[1:0] == 2'b00; }
    constraint c_be    { be != 4'h0; }
    constraint c_soft  { soft state != S_M; }
  endclass

  // --- stage 2: covergroup, cross, illegal_bins, ignore_bins ---------------
  covergroup cg_pair with function sample (st_e x, st_e y);
    option.per_instance = 1;
    cp0 : coverpoint x;
    cp1 : coverpoint y;
    xp  : cross cp0, cp1 {
      illegal_bins mm = binsof(cp0) intersect {S_M} && binsof(cp1) intersect {S_M};
      ignore_bins  ii = binsof(cp0) intersect {S_I} && binsof(cp1) intersect {S_I};
    }
  endgroup

  cg_pair cg;

  // --- stage 3: concurrent assertions --------------------------------------
  default clocking probe_cb @(posedge clk); endclocking

  a_handshake: assert property (req |-> ##[1:5] gnt)
    else $error("tool_check: handshake property failed");

  initial begin
    item         it;
    int          ok;
    int          n_legal;
    int unsigned assoc [int];

    cg = new();
    it = new();

    n_legal = 0;
    for (int i = 0; i < 50; i++) begin
      ok = it.randomize() with { addr inside {[16:64]}; };
      if (ok && it.addr[1:0] == 2'b00 && it.be != 4'h0) n_legal++;
    end
    $display("[tool_check] stage 1  classes + constraints   : %0d/50 legal solutions", n_legal);

    // Associative arrays and queues, used heavily by the scoreboard.
    assoc[32'hdead_beef] = 1;
    assoc[32'h0000_0010] = 2;
    $display("[tool_check] stage 1b assoc arrays            : %0d entries", assoc.num());

    cg.sample(S_S, S_S);
    cg.sample(S_M, S_I);
    cg.sample(S_I, S_E);
    cg.sample(S_E, S_I);
    $display("[tool_check] stage 2  covergroup + crosses    : %0.2f %% inst coverage",
             cg.get_inst_coverage());
    $display("[tool_check] stage 2b $get_coverage()         : %0.2f %%", $get_coverage());

    @(posedge clk);
    req <= 1'b1;
    @(posedge clk);
    req <= 1'b0;
    @(posedge clk);
    gnt <= 1'b1;
    @(posedge clk);
    gnt <= 1'b0;
    repeat (4) @(posedge clk);
    $display("[tool_check] stage 3  concurrent assertions   : compiled and evaluated");

    $display("");
    $display("[tool_check] ALL STAGES PASSED -- this tool can build the braytcache testbench");
    $display("[tool_check] now run 'make check-uvm' to confirm the UVM library is present");
    $finish;
  end

endmodule
