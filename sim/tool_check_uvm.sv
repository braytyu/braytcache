`timescale 1ns/1ps

// Minimal UVM capability probe: factory, config_db, phasing, objections and
// analysis connectivity. Separate from tool_check.sv so that a failure here
// means "UVM library missing or not linked" rather than "language feature
// unsupported".
//
//   cd sim && make check-uvm
module tool_check_uvm;

  import uvm_pkg::*;
`include "uvm_macros.svh"

  class txn extends uvm_sequence_item;
    rand bit [7:0] a;
    `uvm_object_utils(txn)
    function new(string name = "txn");
      super.new(name);
    endfunction
  endclass

  class sub extends uvm_subscriber #(txn);
    `uvm_component_utils(sub)
    int n;
    function new(string name, uvm_component parent);
      super.new(name, parent);
    endfunction
    function void write(txn t);
      n++;
    endfunction
  endclass

  class t_check extends uvm_test;
    `uvm_component_utils(t_check)

    sub                     s;
    uvm_analysis_port #(txn) ap;

    function new(string name, uvm_component parent);
      super.new(name, parent);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      s = sub::type_id::create("s", this);
      // Scope must be "" here: set(this,"*") keys on "uvm_test_top.*", which
      // does not match the "uvm_test_top" that get(this,"") looks up.
      uvm_config_db #(int)::set(this, "", "answer", 42);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      ap.connect(s.analysis_export);
    endfunction

    task run_phase(uvm_phase phase);
      txn t;
      phase.raise_objection(this);
      for (int i = 0; i < 5; i++) begin
        t = txn::type_id::create("t");
        if (!t.randomize()) `uvm_error("TOOL_CHECK", "randomize failed")
        ap.write(t);
      end
      #10ns;
      phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
      int got;
      super.report_phase(phase);
      if (!uvm_config_db #(int)::get(this, "", "answer", got)) got = -1;

      `uvm_info("TOOL_CHECK", $sformatf("analysis writes received = %0d (expect 5)", s.n), UVM_NONE)
      `uvm_info("TOOL_CHECK", $sformatf("config_db round trip     = %0d (expect 42)", got), UVM_NONE)
      if (s.n == 5 && got == 42)
        `uvm_info("TOOL_CHECK", "UVM OK -- factory, config_db, phasing and analysis all work", UVM_NONE)
      else
        `uvm_error("TOOL_CHECK", "UVM present but behaving unexpectedly")
    endfunction
  endclass

  initial run_test("t_check");

endmodule
