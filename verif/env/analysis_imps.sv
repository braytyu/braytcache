`ifndef ANALYSIS_IMPS_SV
`define ANALYSIS_IMPS_SV

// Separate write_* entry points so one component can subscribe to several
// different transaction streams. Declared once here, used by both the
// scoreboard and the coverage collector.
`uvm_analysis_imp_decl(_core)
`uvm_analysis_imp_decl(_bus)
`uvm_analysis_imp_decl(_probe)
`uvm_analysis_imp_decl(_axil)

`endif
