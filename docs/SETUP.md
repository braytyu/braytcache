# What the run machine needs

This machine only authors files. Everything below runs on the other machine.

## Hard requirement

The testbench is **UVM 1.2 class-based SystemVerilog**. It needs a simulator with
full SystemVerilog-1800 class, constrained-random, covergroup and SVA support.

**These will NOT work, do not try:**

| Tool | Why not |
|---|---|
| Verilator | No UVM, no classes, no constrained randomisation, no covergroups |
| Icarus Verilog | SystemVerilog class support is far too incomplete |
| GHDL / Yosys | Wrong language / synthesis only |
| Vivado XSim | Runs UVM, but covergroup support is partial — `illegal_bins` in crosses is the core of this project and is unreliable there |
| **ModelSim** Intel FPGA Starter Edition | Not the same product as Questa. Its SystemVerilog support excludes the class/UVM subset. If the installer offers both, you want **Questa**. |

## Step 0 — prove the tool can build this at all

**Do this first. It takes five minutes and it decides everything else.**

```bash
cd sim
make check-sv     # classes, constraints, covergroups, illegal_bins in a cross, SVA
make check-uvm    # UVM library present and linked
```

`tool_check.sv` and `tool_check_uvm.sv` are standalone — they depend on nothing
in the project. Each stage prints as it passes, so a failure names the exact
missing capability rather than burying it in a wall of errors from the real
testbench.

Expected tail of a good `make check-sv`:

```
[tool_check] stage 1  classes + constraints   : 50/50 legal solutions
[tool_check] stage 2  covergroup + crosses    : ..... % inst coverage
[tool_check] stage 3  concurrent assertions   : compiled and evaluated
[tool_check] ALL STAGES PASSED -- this tool can build the cachebrayt testbench
```

### If you are on Questa-Intel FPGA **Starter** Edition

This is the free tier, and its capability set is the open question. The
predecessor product (ModelSim-Intel FPGA Starter) had **no** SystemVerilog
class/testbench support at all, and constrained randomisation, functional
coverage and SVA have historically been licensed features in this tool family.
Your install may or may not include them — `make check-sv` is the answer.

Other Starter-edition constraints to be aware of:

- A **line-count limit** applies to the design. The RTL here is well under
  1000 lines, so this should not bite, but it is why the check files are tiny.
- **Single-threaded**, no optimisation licences. Fine at this scale.
- A free licence file from Intel's Self-Service Licensing Center is usually
  required. Set `LM_LICENSE_FILE` before running anything.
- If `vsim` cannot resolve `uvm_pkg`, the library flag may differ. The default
  is `QUESTA_UVM_LIB=-L mtiUvm`; try `make check-uvm QUESTA_UVM_LIB=` to let
  the tool auto-resolve instead.

### Reading the result

| Outcome | What it means | Do this |
|---|---|---|
| Both checks pass | Full capability. | Proceed to bring-up below. |
| `check-sv` passes, `check-uvm` fails | Language is fine, UVM just is not linked. | Fix the library flag, or compile UVM 1.2 from Accellera sources. Recoverable. |
| `check-sv` fails at **stage 2** | Covergroups unlicensed. | RTL debug locally, run the full UVM environment on EDA Playground. |
| `check-sv` fails at **stage 1** | No class-based verification. | Questa Starter cannot run this testbench. Use EDA Playground for all UVM work and keep Questa for waveform debug of the RTL. |

A stage-1 or stage-2 failure is **not** a defect in the project — it is a licence
boundary. The split that still works well: debug the RTL with waveforms locally,
run the verification environment on Playground.

## Host tools (any path)

| Tool | Needed for | Notes |
|---|---|---|
| POSIX shell | `make regress`, `make bugs` | These use `for`/`grep`/`mkdir -p`. On Windows use **Git Bash**, MSYS2 or WSL — `cmd.exe` will not run them. |
| GNU Make | everything in `sim/` | Bundled with Git Bash / MSYS2 / WSL. |
| Python 3.8+ | `bundle_playground.py` only | Only needed if you use EDA Playground. |
| UVM 1.2 library | the testbench | Bundled with Questa, VCS and Xcelium — the Makefile pulls the bundled copy. Only download from Accellera if your simulator has none. |

All paths in `cachebrayt.f` are relative, so **run `make` from inside `sim/`**.

## Bring-up order

Do not start with `regression_test`. Work up in this order so a failure tells you
something specific.

| Step | Command | What it proves |
|---|---|---|
| 1 | `make questa-compile` | Syntax and elaboration. No simulation runs. |
| 2 | `make questa TEST=smoke_test PLUS=+num_txns=5` | Clocking, reset, one agent, one transaction end to end. |
| 3 | `make questa TEST=smoke_test` | Full smoke, both cores. |
| 4 | `make questa TEST=random_test` | Fills, evictions, writebacks. |
| 5 | `make questa TEST=pingpong_test` | Real coherence traffic: snoops, dirty intervention, upgrades. |
| 6 | `make questa TEST=producer_consumer_test` | The litmus test. |
| 7 | `make bugs SIM=questa` | Every run **must fail**. A clean run is a hole in the checkers. |
| 8 | `make regress SIM=questa` | All tests x all seeds. |
| 9 | `make questa WAYS=4 SETS=8 TEST=regression_test` | The second geometry. |

Useful during bring-up:

```bash
make questa TEST=smoke_test VERB=UVM_HIGH PLUS=+num_txns=3
make questa TEST=smoke_test PLUS="+num_txns=3 +dump"   # then open dump.vcd
```

## Where it is most likely to break first

These are structural constructs rather than logic, and they are the ones I could
not verify without a compiler:

| Symptom | Cause | Fallback |
|---|---|---|
| Error on `core_if.dut core [NUM_CORES]` in `cache_top` | Interface array as a module port | Flatten to `NUM_CORES` explicit ports, or move the generate loop into `tb_top` |
| `cache_sva` not found / `CORE_ID` unresolved | `bind` target scope | Questa needs `-mfcu` (already set). Otherwise instantiate `cache_sva` directly inside `l1_cache` under an `ifndef SYNTHESIS` |
| Errors inside `cg_mesi` / `cg_share` cross bins | `binsof ... intersect` support | Replace the cross `illegal_bins` with explicit `if` checks in `write_probe` — same checking, less elegant |
| `dut.g_cache[i].u_cache.state_q` unresolved | Hierarchical reference into a generate | Confirm the generate label is `g_cache` and the instance `u_cache` |

## Option A — EDA Playground (zero install, what we are targeting)

1. On this machine run `python3 sim/bundle_playground.py`. It writes
   `playground/design.sv` and `playground/testbench.sv` with every `` `include ``
   expanded inline, because Playground cannot resolve include paths.
2. Copy those two files to the run machine and open <https://edaplayground.com>.
3. Sign in (free). Anonymous sessions cannot use the commercial simulators.
4. Left pane settings:
   - **Testbench + Design**: `SystemVerilog/Verilog`
   - **UVM/OVM**: `UVM 1.2`
   - **Tools & Simulators**: `Aldec Riviera Pro 2023.04` (best UVM support on the
     free tier; Cadence Xcelium also works if offered)
   - **Run Options**: `+UVM_TESTNAME=regression_test +UVM_VERBOSITY=UVM_LOW`
   - Tick **Open EPWave after run** and add `+dump` to Run Options if you want waves
5. Paste `design.sv` into the Design pane and `testbench.sv` into the Testbench pane.
6. Run.

### Playground limitations you must plan around

- There is a CPU-time cap per run. Keep stimulus short with `+num_txns=<n>`
  (the base test reads this plusarg and overrides the sequence length).
- There is no coverage database and no way to merge coverage across runs. The
  environment therefore prints its own coverage table from `final_phase` using
  `get_inst_coverage()` / `$get_coverage()`. That table is the deliverable.
- There is no regression runner. Change `+UVM_TESTNAME` by hand, or paste a
  different seed. Real regressions need Option B.

## Option B — local simulator (recommended before you show this to anyone)

Any one of these is sufficient. Install on the run machine, then:

```bash
cd sim
make questa   TEST=regression_test SEED=3
make vcs      TEST=pingpong_test   SEED=9
make xcelium  TEST=eviction_test   SEED=4
```

| Simulator | Notes |
|---|---|
| Questa / ModelSim (Siemens) | `vlog`/`vsim` on PATH. Ships UVM; the Makefile uses `-mfcu` so the `bind` file sees the target module. University licences are common. |
| Synopsys VCS | `-ntb_opts uvm-1.2` pulls in the bundled UVM. |
| Cadence Xcelium | `xrun -uvm` pulls in the bundled UVM. |

**Questa Intel FPGA Starter Edition** is the realistic free route: free licence
from Intel, runs on Windows and Linux, supports UVM and functional coverage.

What Option B buys you that Playground cannot:

```bash
make regress SIM=questa          # every test x 5 seeds, pass/fail summary
make bugs    SIM=questa          # bug-injection proof (see below)
```

## Build-time configuration

Cache geometry is set by `+define+` and defaulted in `rtl/cache_pkg.sv`:

```bash
make questa WAYS=4 SETS=8 TEST=eviction_test    # 4-way build
make questa WAYS=2 SETS=16                      # default
```

`NUM_WAYS` must be a power of two (the tree-PLRU indexing assumes it); the RTL
checks this at elaboration.

## Bug injection

Five deliberate RTL bugs sit behind `+define+BUG_n`. Each run **must fail** — a
clean run means the checkers are blind to that bug.

| Define | Injected bug | Expected catcher |
|---|---|---|
| `BUG_1` | Snooped `M` line goes to `E` instead of `S` on `ReadShared` | `cg_mesi` illegal bin `m_to_e`, then SWMR |
| `BUG_2` | `CleanUnique` does not invalidate the sharer | SWMR (`M` coexisting with `S`) |
| `BUG_3` | Store hit ignores byte enables | Golden-memory load mismatch |
| `BUG_4` | Dirty victim evicted without a writeback | `cg_mesi` illegal bin `dirty_dropped`, end-of-test memory check |
| `BUG_5` | `ReadShared` always installs `E` | `cg_share` illegal bins, SWMR |

```bash
make questa TEST=regression_test BUG=2 SEED=7
```

## Copying files

Copy the whole `cachebrayt/` directory. Nothing is generated or machine-specific;
`sim/` and `docs/` are plain text. Only `python3` (3.8+) is needed to run the
bundler, and only if you use Playground.
