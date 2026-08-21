# NOTE: NEXERCISED. no targets were ever run successfully. 
#
# All targets were written for a full simulator license. 
# In the absence of a license, the tool_check targets can be used to verify that the
# tool is capable of building the testbench, and the check-uvm target can be
# used to verify that the UVM library is present and linked.
# 
# In the execution of this project, we used Questa vlog.vopt plus Synopsys VCS on EDA playground.
# For execution steps, see ../docs/SETUP.md

TEST          ?= random_test
SEED          ?= 1
WAYS          ?= 2
SETS          ?= 16
LINE          ?= 16
CORES         ?= 2
VERB          ?= UVM_LOW
BUG           ?=
PLUS          ?=

FLIST  = braytcache.f
DEFS   = +define+CFG_NUM_WAYS=$(WAYS) \
         +define+CFG_NUM_SETS=$(SETS) \
         +define+CFG_LINE_BYTES=$(LINE) \
         +define+CFG_NUM_CORES=$(CORES)

ifneq ($(BUG),)
DEFS += +define+BUG_$(BUG)
endif

RUNARGS = +UVM_TESTNAME=$(TEST) +UVM_VERBOSITY=$(VERB) $(PLUS)

# Questa ships a precompiled UVM as the mtiUvm library. Blank this out if your
# install resolves uvm_pkg automatically: make questa QUESTA_UVM_LIB=
QUESTA_UVM_LIB ?= -L mtiUvm

TESTS = smoke_test random_test shared_region_test false_sharing_test \
        pingpong_test eviction_test read_mostly_test store_streak_test \
        producer_consumer_test mesi_walk_test upgrade_race_test \
        regression_test

SEEDS ?= 1 2 3 4 5

.PHONY: help questa vcs xcelium questa-compile vcs-compile xcelium-compile \
        questa-run vcs-run xcelium-run check-sv check-uvm regress bugs clean

# Compile and run are separate targets; never build them concurrently.
.NOTPARALLEL:

help:
	@echo "step 0 - can this tool even build it:"
	@echo "  make check-sv     classes, constraints, covergroups, illegal_bins, SVA"
	@echo "  make check-uvm    UVM library present and linked"
	@echo ""
	@echo "bring-up first:"
	@echo "  make questa-compile | vcs-compile | xcelium-compile   compile + elaborate, no run"
	@echo ""
	@echo "make questa|vcs|xcelium  TEST=<name> SEED=<n> [WAYS=2|4] [BUG=<n>] [PLUS=+num_txns=5]"
	@echo "make regress SIM=questa  - all tests x all seeds"
	@echo "make bugs    SIM=questa  - bug-injection sanity (each run MUST fail)"
	@echo "tests: $(TESTS)"

# ------------------------------------------------- step 0: tool capability
# Run these before anything else. They depend on nothing in the project.

check-sv:
	@mkdir -p logs
	-@vlib work
	vlog -sv -timescale 1ns/1ps tool_check.sv -l logs/check_sv.log
	vsim -c tool_check -do "run -all; quit -f" -l logs/check_sv_run.log

check-uvm:
	@mkdir -p logs
	-@vlib work
	vlog -sv -timescale 1ns/1ps tool_check_uvm.sv -l logs/check_uvm.log
	vsim -c tool_check_uvm $(QUESTA_UVM_LIB) -do "run -all; quit -f" -l logs/check_uvm_run.log

# ---------------------------------------------------------- compile + elab only

questa-compile:
	@mkdir -p logs
	-@vlib work
	vlog -sv -mfcu +acc=rn -timescale 1ns/1ps $(DEFS) -f $(FLIST) -l logs/comp.log
	vsim -c tb_top $(QUESTA_UVM_LIB) -do "quit -f" -l logs/elab.log

vcs-compile:
	@mkdir -p logs
	vcs -full64 -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps \
	    -debug_access+all $(DEFS) -f $(FLIST) -o simv -l logs/comp.log

xcelium-compile:
	@mkdir -p logs
	xrun -elaborate -uvm -sv -timescale 1ns/1ps -access +rwc \
	     $(DEFS) -f $(FLIST) -l logs/comp.log

# --------------------------------------------------------------------- run only
# No recompile. regress uses these so the design is built once per regression
# rather than once per test x seed.

questa-run:
	@mkdir -p logs
	vsim -c tb_top $(QUESTA_UVM_LIB) -sv_seed $(SEED) $(RUNARGS) \
	     -do "run -all; quit -f" -l logs/$(TEST)_$(SEED).log

vcs-run:
	@mkdir -p logs
	./simv +ntb_random_seed=$(SEED) $(RUNARGS) -l logs/$(TEST)_$(SEED).log

xcelium-run:
	@mkdir -p logs
	xrun -R -svseed $(SEED) $(RUNARGS) -l logs/$(TEST)_$(SEED).log

# ------------------------------------------------------------------- full runs

questa:  questa-compile  questa-run
vcs:     vcs-compile     vcs-run
xcelium: xcelium-compile xcelium-run

SIM ?= questa

# One compile, then every test x seed against it.
regress:
	@mkdir -p logs
	@rm -f logs/regress.summary
	@$(MAKE) --no-print-directory $(SIM)-compile
	@for t in $(TESTS); do \
	  for s in $(SEEDS); do \
	    $(MAKE) --no-print-directory $(SIM)-run TEST=$$t SEED=$$s > /dev/null 2>&1; \
	    if grep -qE "UVM_(ERROR|FATAL) *: *[1-9]" logs/$$t\_$$s.log 2>/dev/null; then \
	      echo "FAIL $$t seed=$$s" >> logs/regress.summary; \
	    else \
	      echo "PASS $$t seed=$$s" >> logs/regress.summary; \
	    fi; \
	  done; \
	done
	@cat logs/regress.summary
	@echo "---"; grep -c PASS logs/regress.summary | xargs echo passed:; \
	 grep -c FAIL logs/regress.summary | xargs echo failed:

# Every one of these MUST report failures. A clean run means the testbench is
# blind to that bug and the checker set needs work. Each bug changes the RTL, so
# unlike regress these do need a recompile per iteration.
bugs:
	@for b in 1 2 3 4 5; do \
	  echo "=== BUG_$$b ==="; \
	  $(MAKE) --no-print-directory $(SIM) TEST=regression_test SEED=7 BUG=$$b \
	    > /dev/null 2>&1 || true; \
	  L=logs/regression_test_7.log; \
	  grep -hE "UVM_ERROR *: *[0-9]+|UVM_FATAL *: *[0-9]+" $$L 2>/dev/null | tail -2; \
	  printf "  illegal-bin / assertion hits: %s\n" \
	    "$$(grep -ciE 'illegal|assertion .*fail' $$L 2>/dev/null || true)"; \
	done

clean:
	rm -rf work simv* csrc *.log logs xcelium.d INCA_libs ucli.key \
	       *.vcd *.shm transcript *.mpf *.wlf vsim.dbg
