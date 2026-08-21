`ifndef BUS_ITEM_SV
`define BUS_ITEM_SV

class bus_item extends uvm_sequence_item;

  int unsigned          core_id;
  bus_op_e              op;
  addr_t                addr;
  bit                   shared;
  logic [NUM_CORES-1:0] snoop_hit;
  logic [NUM_CORES-1:0] snoop_pd;
  line_t                data;
  time                  t_start;
  time                  t_end;

  `uvm_object_utils(bus_item)

  function new(string name = "bus_item");
    super.new(name);
  endfunction

  function bit any_hit();
    return |snoop_hit;
  endfunction

  function bit any_pass_dirty();
    return |snoop_pd;
  endfunction

  function string convert2string();
    return $sformatf("BUS c%0d %-16s line=0x%08h shared=%0b hit=%b pd=%b",
                     core_id, op.name(), addr, shared, snoop_hit, snoop_pd);
  endfunction

endclass

`endif
