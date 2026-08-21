`ifndef CACHE_PKG_SV
`define CACHE_PKG_SV

`timescale 1ns/1ps

// Build-time configuration. Override with e.g. +define+CFG_NUM_WAYS=4
`ifndef CFG_NUM_CORES
  `define CFG_NUM_CORES 2
`endif
`ifndef CFG_NUM_SETS
  `define CFG_NUM_SETS 16
`endif
`ifndef CFG_NUM_WAYS
  `define CFG_NUM_WAYS 2
`endif
`ifndef CFG_LINE_BYTES
  `define CFG_LINE_BYTES 16
`endif

package cache_pkg;

  // Cache geometry. DECISION: these live in a package, not as module
  // parameters, because the address field widths and all the types below are
  // derived from them and the UVM classes import the same definitions.
  // SystemVerilog packages cannot be parameterised, hence the defines above.
  parameter int unsigned NUM_CORES  = `CFG_NUM_CORES;
  parameter int unsigned NUM_SETS   = `CFG_NUM_SETS;
  parameter int unsigned NUM_WAYS   = `CFG_NUM_WAYS;
  parameter int unsigned LINE_BYTES = `CFG_LINE_BYTES;

  parameter int unsigned ADDR_W = 32;
  parameter int unsigned DATA_W = 32;
  parameter int unsigned STRB_W = DATA_W / 8;

  parameter int unsigned LINE_W     = LINE_BYTES * 8;
  parameter int unsigned LINE_WORDS = LINE_BYTES / STRB_W;

  // Address split: [ tag | index | word select | byte offset ]
  parameter int unsigned BYTE_OFF_W = $clog2(STRB_W);
  parameter int unsigned OFFSET_W   = $clog2(LINE_BYTES);
  parameter int unsigned WORD_SEL_W = OFFSET_W - BYTE_OFF_W;
  parameter int unsigned INDEX_W    = $clog2(NUM_SETS);
  parameter int unsigned TAG_W      = ADDR_W - INDEX_W - OFFSET_W;
  parameter int unsigned WAY_W      = (NUM_WAYS  > 1) ? $clog2(NUM_WAYS) : 1;
  parameter int unsigned PLRU_W     = (NUM_WAYS  > 1) ? NUM_WAYS - 1     : 1;
  parameter int unsigned CORE_ID_W  = (NUM_CORES > 1) ? $clog2(NUM_CORES) : 1;

  typedef logic [ADDR_W-1:0]     addr_t;
  typedef logic [DATA_W-1:0]     data_t;
  typedef logic [STRB_W-1:0]     strb_t;
  typedef logic [LINE_W-1:0]     line_t;
  typedef logic [TAG_W-1:0]      tag_t;
  typedef logic [INDEX_W-1:0]    index_t;
  typedef logic [WAY_W-1:0]      way_t;
  typedef logic [WORD_SEL_W-1:0] word_sel_t;
  typedef logic [PLRU_W-1:0]     plru_t;

  // Encoded so bit 1 means "has write permission" and bit 0 means "shared".
  typedef enum logic [1:0] {
    MESI_I = 2'b00,
    MESI_S = 2'b01,
    MESI_E = 2'b10,
    MESI_M = 2'b11
  } mesi_e;

  typedef enum logic {
    CORE_LOAD  = 1'b0,
    CORE_STORE = 1'b1
  } core_op_e;

  // ACE-inspired coherent transaction set.
  typedef enum logic [1:0] {
    BUS_READ_SHARED  = 2'b00,  // ACE ReadShared   : fetch line, allow sharing
    BUS_READ_UNIQUE  = 2'b01,  // ACE ReadUnique   : fetch line, invalidate others
    BUS_CLEAN_UNIQUE = 2'b10,  // ACE CleanUnique  : upgrade S->M, no data moved
    BUS_WRITEBACK    = 2'b11   // ACE WriteBack    : evict dirty line to memory
  } bus_op_e;

  parameter logic [1:0] AXI_OKAY = 2'b00;

  // Address decode. Every consumer goes through these rather than slicing the
  // address by hand, so changing the geometry cannot desynchronise them.
  function automatic index_t addr_index(addr_t a);
    return a[OFFSET_W +: INDEX_W];
  endfunction

  function automatic tag_t addr_tag(addr_t a);
    return a[ADDR_W-1 -: TAG_W];
  endfunction

  function automatic word_sel_t addr_word(addr_t a);
    return a[BYTE_OFF_W +: WORD_SEL_W];
  endfunction

  function automatic addr_t line_addr(addr_t a);
    addr_t r;
    r = a;
    r[OFFSET_W-1:0] = '0;
    return r;
  endfunction

  function automatic addr_t make_addr(tag_t t, index_t i);
    return {t, i, {OFFSET_W{1'b0}}};
  endfunction

  // Line and word manipulation, shared by the RTL and the reference model.
  function automatic data_t line_get_word(line_t l, int unsigned w);
    return l[w*DATA_W +: DATA_W];
  endfunction

  function automatic line_t line_set_word(line_t l, int unsigned w, data_t d, strb_t be);
    line_t r;
    r = l;
    for (int unsigned i = 0; i < STRB_W; i++) begin
      if (be[i]) r[w*DATA_W + i*8 +: 8] = d[i*8 +: 8];
    end
    return r;
  endfunction

  function automatic data_t merge_bytes(data_t old_d, data_t new_d, strb_t be);
    data_t r;
    r = old_d;
    for (int unsigned i = 0; i < STRB_W; i++) begin
      if (be[i]) r[i*8 +: 8] = new_d[i*8 +: 8];
    end
    return r;
  endfunction

  // Tree PLRU. Node n (1-based) lives at tree[n-1]; the bit selects the subtree
  // to replace, so an access flips every node on its path to point away.
  function automatic way_t plru_victim(plru_t tree);
    way_t        way;
    int unsigned node;
    logic        b;
    way  = '0;
    node = 1;
    for (int unsigned lvl = 0; lvl < WAY_W; lvl++) begin
      b    = tree[node-1];
      way  = way_t'((way << 1) | way_t'(b));
      node = 2*node + int'(b);
    end
    return way;
  endfunction

  function automatic plru_t plru_update(plru_t tree, way_t way);
    plru_t       nt;
    int unsigned node;
    logic        b;
    nt   = tree;
    node = 1;
    for (int unsigned lvl = 0; lvl < WAY_W; lvl++) begin
      b          = way[WAY_W-1-lvl];
      nt[node-1] = ~b;
      node       = 2*node + int'(b);
    end
    return nt;
  endfunction

endpackage

`endif
