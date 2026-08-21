`ifndef MEM_MODEL_SV
`define MEM_MODEL_SV

// Sparse backing store for the AXI4-Lite slave. Unwritten locations return a
// deterministic function of the address so the scoreboard can predict the
// result of a load from a location the test never wrote.
class mem_model extends uvm_object;

  data_t mem [addr_t];

  `uvm_object_utils(mem_model)

  function new(string name = "mem_model");
    super.new(name);
  endfunction

  static function addr_t word_key(addr_t a);
    return a & ~addr_t'(STRB_W - 1);
  endfunction

  // Deterministic contents for locations the test never wrote, so a load from
  // anywhere still has exactly one correct answer. The scoreboard seeds its
  // golden memory from the same function, removing the X-on-first-read blind spot.
  static function data_t backing_value(addr_t a);
    data_t v;
    v = word_key(a) ^ 32'hdead_0000;
    v = v * 32'h9e37_79b1;
    return v;
  endfunction

  function data_t read(addr_t a);
    addr_t k;
    k = word_key(a);
    if (!mem.exists(k)) mem[k] = backing_value(k);
    return mem[k];
  endfunction

  function void write(addr_t a, data_t d, strb_t be);
    addr_t k;
    k      = word_key(a);
    mem[k] = merge_bytes(read(k), d, be);
  endfunction

  function bit was_written(addr_t a);
    return mem.exists(word_key(a));
  endfunction

endclass

`endif
