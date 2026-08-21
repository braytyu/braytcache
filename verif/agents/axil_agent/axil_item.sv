`ifndef AXIL_ITEM_SV
`define AXIL_ITEM_SV

class axil_item extends uvm_sequence_item;

  rand bit       is_write;
  rand addr_t    addr;
  rand data_t    data;
  rand strb_t    strb;
  bit [1:0]      resp;

  `uvm_object_utils(axil_item)

  function new(string name = "axil_item");
    super.new(name);
  endfunction

  function string convert2string();
    return $sformatf("AXIL %s addr=0x%08h data=0x%08h strb=%b resp=%0d",
                     is_write ? "WR" : "RD", addr, data, strb, resp);
  endfunction

endclass

`endif
