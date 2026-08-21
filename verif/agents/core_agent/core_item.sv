`ifndef CORE_ITEM_SV
`define CORE_ITEM_SV

class core_item extends uvm_sequence_item;

  // Stimulus fields are rand; rdata and the timestamps are filled in by the
  // driver and monitor once the transaction completes.
  rand core_op_e    op;
  rand addr_t       addr;
  rand data_t       wdata;
  rand strb_t       be;
  rand int unsigned pre_delay;

  data_t       rdata;
  int unsigned core_id;
  time         start_time;
  time         end_time;

  `uvm_object_utils(core_item)

  // Legality only. Traffic shaping (address region, load/store mix) belongs to
  // the sequences so the same item can serve every stimulus pattern.
  constraint c_word_aligned { addr[BYTE_OFF_W-1:0] == '0; }
  constraint c_be_load      { op == CORE_LOAD  -> be == '1; }
  constraint c_be_store     { op == CORE_STORE -> be != '0; }
  constraint c_pre_delay    { soft pre_delay inside {[0:6]}; }

  function new(string name = "core_item");
    super.new(name);
  endfunction

  function void do_copy(uvm_object rhs);
    core_item o;
    super.do_copy(rhs);
    if (!$cast(o, rhs)) `uvm_fatal("CORE_ITEM", "do_copy type mismatch")
    op         = o.op;
    addr       = o.addr;
    wdata      = o.wdata;
    be         = o.be;
    pre_delay  = o.pre_delay;
    rdata      = o.rdata;
    core_id    = o.core_id;
    start_time = o.start_time;
    end_time   = o.end_time;
  endfunction

  function string convert2string();
    if (op == CORE_STORE)
      return $sformatf("c%0d ST  addr=0x%08h be=%b wdata=0x%08h", core_id, addr, be, wdata);
    else
      return $sformatf("c%0d LD  addr=0x%08h rdata=0x%08h", core_id, addr, rdata);
  endfunction

endclass

`endif
