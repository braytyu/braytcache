`ifndef PROBE_ITEM_SV
`define PROBE_ITEM_SV

class probe_item extends uvm_sequence_item;

  int unsigned core_id;
  int unsigned set_idx;
  int unsigned way_idx;
  tag_t        old_tag;
  tag_t        new_tag;
  mesi_e       old_state;
  mesi_e       new_state;
  line_t       new_data;
  time         t;

  `uvm_object_utils(probe_item)

  function new(string name = "probe_item");
    super.new(name);
  endfunction

  function addr_t new_line_addr();
    return make_addr(new_tag, index_t'(set_idx));
  endfunction

  function addr_t old_line_addr();
    return make_addr(old_tag, index_t'(set_idx));
  endfunction

  function string convert2string();
    return $sformatf("PROBE c%0d set=%0d way=%0d %s->%s tag 0x%0h->0x%0h",
                     core_id, set_idx, way_idx, old_state.name(), new_state.name(),
                     old_tag, new_tag);
  endfunction

endclass

`endif
