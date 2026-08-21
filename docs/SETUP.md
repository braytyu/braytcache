# Setup and reproduction

Every command, option and setting used to produce the results in
[../README.md](../README.md). Follow it top to bottom on a clean machine and you
get the same twelve passes, the same five bug detections and the same coverage
numbers.

**Contents:** [Step 0 — tool capability](#step-0--what-the-free-questa-tier-can-and-cannot-do)
· [What you need](#what-you-need)
· [Step 1 — Questa](#step-1--questa-compile-and-elaborate)
· [Step 2 — bundle](#step-2--bundle-for-eda-playground)
· [Step 3 — Playground setup](#step-3--eda-playground-account-and-settings)
· [Step 4 — every test](#step-4--every-test-with-its-exact-options)
· [Step 5 — bug injection](#step-5--bug-injection)
· [Step 6 — second geometry](#step-6--the-second-geometry)
· [Reading a result](#reading-a-result)
· [Things that cost time](#things-that-cost-time)

## The two machines

Two machines, and it matters which is which:

| Machine | Role | Runs |
|---|---|---|
| **Authoring machine** | where the code is written and edited | nothing — no compile, no simulation |
| **Run machine** | where Questa is installed | everything in this document |

Transfer is a manual copy of the `braytcache/` directory, authoring to run, one
direction only. There is no staleness detection — see
[DEBUG_LOG O-003](DEBUG_LOG.md).

Two paths appear throughout. Substitute your own:

| Placeholder | Meaning |
|---|---|
| `<REPO>` | wherever `braytcache/` lives on the run machine |
| `<QUESTA>` | the Questa install root, e.g. `C:/altera/<version>/questa_fse` |

**If either path contains a space, it has to be quoted** — `{...}` in Questa's
Tcl transcript, `"..."` in bash. This is the single most common cause of a "file
not found" that looks like a missing file.

Three places take commands, and they are not interchangeable:

| Where | What goes there |
|---|---|
| **Questa Transcript** pane | `vlib`, `vlog`, `vopt` — Tcl, not shell |
| **bash** on the authoring machine | `python sim/bundle_playground.py` only |
| **edaplayground.com** in a browser | every simulation |

Git Bash is fine for the one Python command. Note that Git Bash ships **no GNU
Make**, so nothing in `sim/Makefile` runs there — see the last section.

## Step 0 — what the free Questa tier can and cannot do

**This was the first question and it decided the whole flow. The answer is
already known — recorded here so nobody has to rediscover it.**

Questa–Intel/Altera FPGA **Starter** Edition 2025.2:

| Capability | Result |
|---|---|
| `vlog` — compile class-based SystemVerilog, covergroups, SVA | **works** |
| `vopt` — elaborate the full UVM testbench | **works** |
| `vsim` — *load and run* a design containing `randomize`/`covergroup` | **blocked**, no `svverification` licence |

So Questa is a compile-and-elaborate tool for this project and nothing more. All
simulation happens on EDA Playground under VCS. That is a licence boundary, not
a defect in the project.

Two standalone probes live in `sim/` because they establish this in about a
minute on a new machine, and they depend on nothing else in the repo:

```tcl
vlog -sv tool_check.sv
vsim -c tool_check -do "run -all; quit -f"
```

`tool_check.sv` reports per stage — classes and constraints, then covergroups
with `illegal_bins` in a cross, then concurrent assertions — so a failure names
the exact missing capability instead of burying it in cascading errors.
`tool_check_uvm.sv` separately confirms the UVM library is present and linked.

On the Starter tier the `vlog` line passes and the `vsim` line fails with a
licence error. **That is the expected result**, and it is what sent this project
to EDA Playground.

### Simulators that will not work at all

| Tool | Why not |
|---|---|
| Verilator | No UVM, no classes, no constrained randomisation, no covergroups |
| Icarus Verilog | SystemVerilog class support far too incomplete |
| GHDL / Yosys | Wrong language / synthesis only |
| Vivado XSim | Runs UVM, but covergroup support is partial — `illegal_bins` in crosses is the core of this project and is unreliable there |
| **ModelSim** Intel FPGA Starter | Not the same product as Questa; excludes the class/UVM subset. If the installer offers both, you want **Questa**. |

## What you need

| Tool | Needed for | Notes |
|---|---|---|
| Questa FPGA Edition 2025.2 | Steps 0 and 1 | Free Starter licence from Intel's Self-Service Licensing Center. Set `LM_LICENSE_FILE` before launching. |
| Python 3.8+ | `bundle_playground.py` | Standard library only, no packages to install. |
| A browser + EDA Playground account | every simulation | Free. Must be logged in. |
| UVM 1.2 library | the testbench | Playground supplies it. Questa's bundled 1.1d is enough to elaborate against. |
| GNU Make | nothing, currently | Only for the untested `sim/Makefile` targets. Not in Git Bash. |

All paths in `braytcache.f` are relative, so **run `make` from inside `sim/`**.

## Step 1 — Questa: compile and elaborate

This catches syntax and structural errors across all 37 compiled files without
simulating anything. It is the fast filter; do it before every Playground paste.

Type these into Questa's **Transcript** pane. They are Questa commands, not
shell commands.

```tcl
cd {<REPO>/braytcache/sim}
vlib work
vlog -sv -mfcu +acc=rn -timescale 1ns/1ps -f braytcache.f
vopt +acc=rn -L mtiUvm tb_top -o tb_opt
```

**The braces matter** if any directory in the path has a space in it — Tcl needs
`{...}` around the whole path. In a bash shell use `"..."` instead.

Expected: `vlog` reports **0 errors, 0 warnings**; `vopt` reports **0 errors**
and prints `-- Loading module cache_sva`, which confirms the SVA bind attached.

Flags that are not optional:

| Flag | Why |
|---|---|
| `-sv` | SystemVerilog, not Verilog-2001 |
| `-mfcu` | single compilation unit — without it the `bind` in `tb_top` cannot see `l1_cache` |
| `+acc=rn` | keeps nets and registers visible for the whitebox probe and for waveforms |
| `-L mtiUvm` | Questa's bundled UVM 1.1d library |

Do **not** use Questa's *New Project* wizard. There is no project file. You
`cd` into `sim/` and issue the four commands above.

## Step 2 — bundle for EDA Playground

Playground cannot resolve `+incdir`, so the tree is flattened into the two panes
it expects, with all 21 `` `include `` directives expanded inline.

On the authoring machine:

```bash
python sim/bundle_playground.py
```

Writes:

| File | Contents | Paste into |
|---|---|---|
| `playground/design.sv` | RTL + SVA. No UVM dependency, compiles first. | **Design** pane |
| `playground/testbench.sv` | UVM package + `tb_top` | **Testbench** pane |

**Which pane to re-paste** after an edit — the bundler rewrites both every time,
but usually only one has changed:

| You edited | Re-paste |
|---|---|
| `rtl/`, `verif/sva/` | Design |
| `verif/agents/`, `verif/env/`, `verif/tests/`, `verif/tb/` | Testbench |

## Step 3 — EDA Playground account and settings

1. Go to <https://edaplayground.com> and **create an account**. Verify the email.
2. **Log in.** Anonymous sessions cannot use the commercial simulators — this is
   not optional, and the failure mode is that VCS simply is not in the dropdown.
3. Set the left-hand panel exactly as follows:

| Setting | Value |
|---|---|
| Testbench + Design | `SystemVerilog/Verilog` |
| UVM / OVM | **`UVM 1.2`** |
| Tools & Simulators | **`Synopsys VCS`** |
| Compile Options | *(empty, unless injecting a bug or changing geometry)* |
| Run Options | `+UVM_TESTNAME=<test>` *(see the table in Step 4)* |

4. Leave every checkbox off. Two matter later: *Open EPWave after run* together
   with `+dump` in Run Options for waveforms, and *Use run.bash* to loop several
   `+UVM_TESTNAME` values in one session.
5. Paste `design.sv` into the **Design** pane, `testbench.sv` into **Testbench**.
6. **Run**.

### What Playground actually does with those two panes

A single VCS invocation. Worth knowing, because every error message is reported
against `design.sv` or `testbench.sv` line numbers rather than the original
files:

```bash
vcs -full64 -sverilog -timescale=1ns/1ns +incdir+$UVM_HOME/src \
    $UVM_HOME/src/uvm.sv $UVM_HOME/src/dpi/uvm_dpi.cc \
    design.sv testbench.sv  &&  ./simv +UVM_TESTNAME=<test>
```

So UVM is compiled from source on every run (about 15 s), the two panes are just
two files in order, and — critically — **Compile Options are `vcs` switches while
Run Options are `simv` plusargs.** That is why `+define+` goes in one box and
`+UVM_TESTNAME` in the other.

## Step 4 — every test, with its exact options

Compile Options is **empty** for all twelve. Only Run Options change.

| Test | Run Options |
|---|---|
| `smoke_test` | `+UVM_TESTNAME=smoke_test +num_txns=5` |
| `mesi_walk_test` | `+UVM_TESTNAME=mesi_walk_test` |
| `pingpong_test` | `+UVM_TESTNAME=pingpong_test +num_txns=30` |
| `eviction_test` | `+UVM_TESTNAME=eviction_test +num_txns=30` |
| `upgrade_race_test` | `+UVM_TESTNAME=upgrade_race_test` |
| `producer_consumer_test` | `+UVM_TESTNAME=producer_consumer_test` |
| `false_sharing_test` | `+UVM_TESTNAME=false_sharing_test +num_txns=30` |
| `store_streak_test` | `+UVM_TESTNAME=store_streak_test` |
| `read_mostly_test` | `+UVM_TESTNAME=read_mostly_test +num_txns=30` |
| `shared_region_test` | `+UVM_TESTNAME=shared_region_test +num_txns=30` |
| `random_test` | `+UVM_TESTNAME=random_test` |
| `regression_test` | `+UVM_TESTNAME=regression_test` |

`+num_txns` is **per core** — `+num_txns=30` on a two-core build issues sixty
accesses. It only has an effect on the seven tests above that carry it; the other
five size themselves differently and ignore it entirely. `mesi_walk`,
`upgrade_race` and `producer_consumer` override `body()` and are sized by rounds
or messages; `store_streak` is sized by `n_streaks`; `regression` re-randomises a
length per phase.

Optional additions to Run Options:

| Plusarg | Effect |
|---|---|
| `+UVM_VERBOSITY=UVM_HIGH` | full transaction-level tracing; very noisy |
| `+dump` | writes `dump.vcd`; tick *Open EPWave after run* |

## Step 5 — bug injection

Five deliberate RTL mutations. **Every one of these runs must fail.** A clean run
means the checkers are blind to that bug.

Put the define in **Compile Options**, keep Run Options as normal:

| Compile Options | Run Options | Expected result |
|---|---|---|
| `+define+BUG_1` | `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_mesi` illegal bin `m_to_e` at ~1.5 us, **exit 1** |
| `+define+BUG_2` | `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_share` illegal bin `ms` at ~7.7 us, **exit 1** |
| `+define+BUG_3` | `+UVM_TESTNAME=eviction_test +num_txns=30` | 11 scoreboard `UVM_ERROR`s, runs to completion, **exit 0** |
| `+define+BUG_4` | `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_mesi` illegal bin `dirty_dropped` at ~3.7 us, **exit 1** |
| `+define+BUG_5` | `+UVM_TESTNAME=eviction_test +num_txns=30` | `cg_share` illegal bin `se` at ~1.8 us, **exit 1** |

`BUG_3` exiting **0** is not a mistake — it is the point. It violates no protocol
rule, so no illegal bin fires and nothing aborts; only the golden memory catches
it. A regression script keyed on exit code alone would call that run a pass.

`eviction_test` is used for all five because it is the only test that produces
writebacks, and `BUG_2` / `BUG_4` are undetectable without them. See
[DEBUG_LOG O-007](DEBUG_LOG.md).

## Step 6 — the second geometry

| Compile Options | Run Options |
|---|---|
| `+define+CFG_NUM_WAYS=4 +define+CFG_NUM_SETS=8` | `+UVM_TESTNAME=eviction_test +num_txns=30` |

Confirm it took effect from the first line of the log:

```
[CFG] cores=2 sets=8 ways=4 line=16B
```

**Clear the Compile Options box afterwards.** Playground keeps whatever is in
that field between runs, and a stale geometry define is invisible in the Run
Options — the `[CFG]` line is the only thing that will tell you.

Available geometry defines, all defaulted in `rtl/cache_pkg.sv`:

| Define | Default | Constraint |
|---|---|---|
| `CFG_NUM_CORES` | 2 | `cg_share` assumes exactly 2 |
| `CFG_NUM_SETS` | 16 | power of two |
| `CFG_NUM_WAYS` | 2 | power of two (tree-PLRU indexing) |
| `CFG_LINE_BYTES` | 16 | power of two, ≥ 4 |

## Reading a result

Three different mechanisms report failures, and they behave differently. Check
all three — see [DEBUG_LOG O-005](DEBUG_LOG.md).

| Mechanism | Appears in UVM summary | Aborts run | Exit code |
|---|---|---|---|
| Scoreboard `uvm_error` | yes | no | 0 |
| SVA assertion failure | **no** | no | 0 |
| Covergroup illegal bin | **no** | **yes** | 1 |

A clean run prints, in order: the `[CFG]` line, `[SB]` traffic counters, the
`[COV]` table, then `UVM_ERROR : 0`.

**Read the `[SB]` counters even when everything passes.** They are a cheap
summary of which protocol paths the stimulus actually reached, and they are the
only way to notice a test is not doing what its name claims. That check caught a
documentation error on a green run — [DEBUG_LOG O-010](DEBUG_LOG.md).

## Things that cost time

| Symptom | Cause | Fix |
|---|---|---|
| Results look wrong for no reason | **Compile Options still holds a define from the previous run.** Playground persists that field; Run Options gives no hint. | Read the `[CFG]` line at time 0 on every run. Clear the box. |
| Synopsys VCS missing from the simulator dropdown | Not logged in | Log in. Anonymous sessions get open-source simulators only. |
| An edit had no effect | Bundled but pasted into the wrong pane | `rtl/` and `verif/sva/` → Design; everything else → Testbench |
| Playground errors point at line numbers that do not exist | Correct — they refer to the flattened `design.sv` / `testbench.sv` | Map back by searching the surrounding text in the original file |
| Questa: "file not found" on a path that exists | A space somewhere in the path | Wrap in `{...}` in Tcl, `"..."` in bash |
| `bind` produced no assertions, silently | `bind` at compilation-unit scope | Keep it inside `tb_top`. [D-001](DEBUG_LOG.md) |
| Run ends immediately with `UVM_FATAL [RUNPHSTIME]` | Delay before `run_test()` | `#0`, not `#1`. [D-002](DEBUG_LOG.md) |
| Compile succeeded but nothing changed | Forgot to re-bundle | `python sim/bundle_playground.py` after **every** `.sv` edit |

## What actually broke during bring-up

These were the open structural risks before anything had been compiled. All four
are resolved; the full reasoning for each is in [DEBUG_LOG.md](DEBUG_LOG.md).

| Risk | Outcome |
|---|---|
| Interface array as a module port in `cache_top` | Compiled fine on both tools. No change needed. |
| `bind` target scope for `cache_sva` | **Broke.** Questa rejected a compilation-unit-scope bind; moved inside `tb_top`. [D-001](DEBUG_LOG.md) |
| `binsof ... intersect` in cross `illegal_bins` | Compiled and fired correctly on both tools. This is the core of the project and it works. |
| `dut.g_cache[i].u_cache.state_q` hierarchical probe | Resolved correctly. `+acc=rn` is what keeps it visible. |

Three further defects surfaced only under simulation: [D-002](DEBUG_LOG.md)
(`#1` before `run_test()` fatals under UVM 1.2), [D-003](DEBUG_LOG.md)
(`snoop_ack` asserted while unselected), [D-004](DEBUG_LOG.md) (`cg_alloc`
sampled on the wrong predicate) and [D-005](DEBUG_LOG.md) (the litmus checker
asserted a property the design never promised).

## If you have a full simulator licence

Everything above works around Questa Starter's `svverification` limit and
Playground's CPU cap. With a full Questa, VCS or Xcelium licence the flow
collapses to one command and unlocks the two things this project cannot
currently do: **multi-seed regression** and **cross-run coverage merge**.

`sim/Makefile` carries `questa`, `vcs`, `xcelium`, `regress` and `bugs` targets
written for exactly that case.

> **These targets have never been run.** They were written before the licence
> boundary was known, and the flow moved to Playground before they could be
> exercised. Treat them as a starting point, not as tested infrastructure. Git
> Bash also does not ship GNU Make, so they need MSYS2, WSL or Linux.

```bash
cd sim
make questa  TEST=regression_test SEED=3
make regress                       # all tests x seeds
make bugs                          # all five injected bugs
make questa  WAYS=4 SETS=8 TEST=eviction_test
```

All paths in `braytcache.f` are relative, so run `make` from inside `sim/`.

## Run machine checklist

| # | Requirement | Check it with |
|---|---|---|
| 1 | Questa FPGA Starter Edition on `PATH` | `vsim -version` |
| 2 | Intel licence file | `echo $LM_LICENSE_FILE` |
| 3 | Python 3.8+ | `python --version` |

Questa is branded *Intel* in older Quartus releases and *Altera* in newer ones —
same product. Add `.../questa_fse/win64` to `PATH`:

```bash
export PATH="<QUESTA>/win64:$PATH"
export LM_LICENSE_FILE="/path/to/license.dat"
```

## VS Code and Questa are doing different jobs

| Tool | Job |
|---|---|
| VS Code | Text editor. Writes `.sv` files. Compiles and simulates **nothing**. |
| Questa | Compiler and elaborator. Reads those files and reports errors. Cannot simulate them on this licence tier. |
| EDA Playground | Simulator. Runs the tests and prints the results. |

VS Code and Questa point at the same directory on disk. There is no project file
to create or import.

## Transferring to the run machine

Copy the whole `braytcache/` directory across by hand. Nothing in it is
generated or machine-specific, so a plain copy is enough — no build step, no
path fixups, no tooling required on the authoring side.

**Copy in one direction only.** All editing happens on the authoring machine.
If both copies get edited you will be reconciling them by hand in the middle of
a debug session, which is the worst possible time. When a run fails, take the
error text back to the authoring machine, fix it there, and re-copy.

These are simulator build products, regenerated on every run — do not copy them
back and do not commit them:

```
sim/work/   sim/logs/   sim/transcript   *.wlf   *.vcd   modelsim.ini
playground/design.sv    playground/testbench.sv
```

`playground/` is generated by the bundler and is in `.gitignore`. The rest are
Questa's; deleting `sim/work/` and re-running `vlib work` is the fix for any
compile error that survives an edit.
