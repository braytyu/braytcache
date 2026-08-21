# Project progress

Living log for **braytcache**. Updated at the end of every working session.

Defects found by the tools are written up in detail in
[docs/DEBUG_LOG.md](docs/DEBUG_LOG.md) — symptom, root cause, reasoning and fix
for each. This file tracks status and decisions.

---

## Goal

A two-core, 2-way set-associative, write-back L1 data cache maintaining **MESI
coherence** over a snooping interconnect, verified with a constrained-random
**UVM** environment. Portfolio project aimed at DV/verification roles: the RTL
is deliberately modest, the verification environment is the point.

---

## Current status

| Item | State |
|---|---|
| RTL | Complete, compiles and elaborates clean |
| UVM environment | Complete, **runs end to end** |
| Assertions | Complete, **caught a real protocol bug on the first run** |
| Build flow | Complete (filelist, Makefile, Playground bundler) |
| Tool capability confirmed | Questa: `vlog`/`vopt` only. VCS on Playground: full |
| Simulation | **12 of 12 tests pass** on VCS/Playground |
| Regression run | Not yet — Playground has no runner |
| Coverage closure | **98.92 %** best single run (`regression_test`); no cross-run merge |
| Bug injection | **5 of 5 detected** — the matrix is complete |
| Geometries | **2 of 2 pass** — 2-way/16-set and 4-way/8-set, unchanged sources |

**Immediate next action:** nothing outstanding in the planned scope. What remains
is blocked on tooling: multi-seed regression and cross-run coverage merge both
need a simulator without Playground's runner and CPU-time limits.

### Full repo audit, 2026-08-21

Read every file top to bottom looking for anything a reviewer could challenge.
The RTL and the checkers came through clean; the documentation did not.

**Documentation errors, all fixed.** The README claimed **40 files** compiled
and **21 `` `include ``** directives expanded. The real numbers are **37** (13
in `braytcache.f` + 24 included into `cache_uvm_pkg.sv`) and **24**. The 40 came
from a real `vlog` log and was carried forward without ever being re-derived —
which is exactly how a number stops being evidence.

It also claimed *"every test accepts `+num_txns`"*. Five do not: `mesi_walk`,
`upgrade_race` and `producer_consumer` override `body()` and are sized by rounds
or messages, `store_streak` is sized by `n_streaks`, and `mixed_vseq`
re-randomises a length per phase. Anyone reproducing a result by passing
`+num_txns` to those five would silently get the default and wonder why their
counts did not match.

Three smaller ones: `make questa BUG=n` / `make bugs` / `make questa-compile`
were presented as the way to run things, which contradicts the Makefile's own
new header saying no target has ever run; `upgrade_race_test` was described as
using *"six randomly chosen lines"* when the round *count* is randomised and the
lines are consecutive from the region base; and the `## Bug injection results`
heading sat *above* the `BUG_5` writeup, orphaning it and the illegal-bin
discussion under a summary. The table is now `### All five, side by side` at the
end where it belongs, with the ambiguity in its `Time` column resolved — those
are first-error times, not run lengths, which matters for `BUG_3` (first error
7.64 us, `$finish` 18.66 us).

**Two real code findings, both recorded rather than fixed:**

- **[O-011](docs/DEBUG_LOG.md)** — `cg_core`'s `cp_be` uses `bins partial =
  default`, and per IEEE 1800 §19.5 a `default` bin **does not participate in a
  cross**. So `x_op_be` never sees a genuinely partial byte enable, and the
  covergroup reports 99.11 % without any indication that a category of stimulus
  is unmeasured. This is O-006 from the other direction: there, full coverage
  did not imply correctness; here, a high percentage does not imply the model
  measures what it appears to.
- **[O-012](docs/DEBUG_LOG.md)** — `bundle_playground.py` hard-codes a second
  copy of the file list that nothing checks against `braytcache.f`. A file added
  to one and not the other compiles clean in Questa and vanishes on Playground.
  Has not bitten only because the file set stopped changing first.

Both were left alone deliberately. Fixing the `default` bin changes every
coverage figure in the README, all of which came from real runs; the honest
order is fix-then-rerun, not fix-and-leave-stale-numbers. Fixing the bundler is
a build change, and build changes made after the last green run are how a
reproducible result quietly stops being reproducible.

**Smaller things noted, no action:** `mem_model::backing_value()` multiplies a
word-aligned address by an odd constant, so its low two bits are always zero and
that slice of the value space never appears in unwritten memory — harmless,
since the scoreboard seeds from the same function, but a weaker reference pattern
than it looks. `mem_model::was_written()` is dead code. `bus.snoop_hit` /
`snoop_pass_dirty` / `snoop_data` are ungated and hold stale values between
snoops; correctness depends entirely on `coherence_bus` qualifying them with
`snoop_ack`, which is the same shape as [D-003](docs/DEBUG_LOG.md) and worth a
comment if the interconnect is ever rewritten. The probe monitor sweeps
`NUM_SETS × NUM_WAYS` per core every cycle, which is fine at 512 bytes and would
not be at a realistic geometry.

**Checked and found correct**, so it can be said with confidence: the PLRU tree
indexing at both 2 and 4 ways; `wb_needed` withdrawing on a snoop that downgrades
the victim; `vic_q` latched to `hit_way` on the upgrade path so a degraded
`CleanUnique` refills the right way; the D-004 `cg_alloc` predicate; the ordering
argument behind `cg_share` never sampling a transient illegal pair (the sharer
downgrades at snoop-ack, the requester commits two cycles later); the ten
transitions in `mesi_walk_vseq` being exactly the ten legal MESI moves; and the
`#0` before `run_test()` resolving the config_db ordering without advancing time.

### Presentation pass, 2026-08-21: results on the first screen, SETUP.md rewritten

Three cleanup items ahead of showing this to anyone.

**README status banner.** The results were previously reachable only by scrolling
past ~800 lines of design rationale. A reader who does not scroll saw a design
document, not a verification result. Added a banner immediately under the opening
line: 12/12 tests, 5/5 bugs, 2/2 geometries, 98.92 %, 5 defects — then a
four-row table (RTL / Verification / Toolchain / Evidence) with jump links, and
the two findings worth arguing about. Everything in it is a number produced by a
run, not an adjective.

**`docs/SETUP.md` rewritten.** It had drifted badly — it still named *Aldec
Riviera Pro* as the Playground simulator (we used **Synopsys VCS**), its bring-up
order was nine `make questa` invocations that were never once executed, and its
"where it is most likely to break first" table was speculation written before
anything had compiled. All of it was answered months of debugging ago.

Restructured into a linear reproduction guide: Step 0 states the Questa
capability outcome as fact (vlog works, vopt works, `vsim` licence-blocked)
rather than posing it as an open question; Step 1 gives the four literal Tcl
commands with the flags that are not optional and why; Steps 3–4 give the exact
Playground settings and a **table of the Run Options for all twelve tests**;
Step 5 the five `+define+BUG_n` compile options with expected catcher, time and
exit code; Step 6 the geometry defines. Added a "things that cost time" table
whose first row is the Compile Options field persisting between runs — the
failure mode that wastes the most time because it produces plausible-looking
wrong results with no error.

The document now claims only what was observed. Anything untested says so.

**`sim/Makefile` kept, with a caveat header.** It was the obvious deletion
candidate: not one of its targets has ever run. But it encodes the multi-seed
regression and bug-injection sweep this project would need next given a licence,
and deleting it would remove the record of that intent. Kept with a header
stating plainly that it is unexercised and why. A file that documents its own
untested status is more useful than a missing file.

**Trim list: nothing else to remove.** Audited all 44 files. The two
`tool_check*.sv` probes look like scaffolding but establish the licence boundary
in a minute on a new machine and are the evidence behind O-002 — keep. Every
`.sv` in `rtl/` and `verif/` is compiled. `braytcache.f` and
`bundle_playground.py` drive the real flow. Four markdown files, no overlap.
The repo is already lean.

*(The open "40 files" question from this entry was settled by the audit above:
the real count is 37.)*

### Suite complete, 2026-08-21: `regression_test` passes — 12 of 12

```
[SB]  loads=96 stores=173 touched_words=59
      ReadShared=53 ReadUnique=70 CleanUnique=22 WriteBack=4
      state transitions=248  invariant sweeps=248
[COV] cg_core 99.11 | cg_bus 98.61 | cg_mesi 96.84
      cg_alloc 98.96 | cg_axil 100.00 | cg_share 100.00 | OVERALL 98.92 %
```

**Best single run in the project at 98.92 %**, and the only run to produce all
four bus operations in quantity — `ReadShared=53 ReadUnique=70 CleanUnique=22
WriteBack=4`. Chaining 3–6 phases without an intervening reset beats every
single-pattern test on five of six covergroups, which is the argument for the
composite test existing.

269 accesses across 59 distinct words, 248 state transitions, zero errors.

**The suite is now fully characterised.** Added two comparison tables to the
README findings section: which test closes which covergroup, and the coherence
intensity spread. The second is the more interesting — bus transactions per 100
accesses ranges from **5.6** (`store_streak`, nearly bus-silent) to **103**
(`random_test`, missing on almost every access with writebacks on top). An
eighteen-fold spread is the evidence that the twelve tests are genuinely
different workloads rather than variations on one.

### Failure and fix, 2026-08-21: `producer_consumer_test` — D-005

Seven `UVM_ERROR`s from the sequence, **zero** from the scoreboard. The failure
was in the litmus test, not the RTL, and the direction of the mismatch proves it:
a consistency violation shows a payload *older* than the flag, and every mismatch
here was *newer* by exactly one message. Nothing in a coherence bug produces data
from the future.

Two separate defects, both in the verification code:

- The expectation required *exactly* `payload_of(seen_flag)`, which only holds if
  the producer is quiesced. Producer and consumer run in a `fork`, so the
  producer can advance between the consumer's flag read and its data read. The
  property the design actually offers is that the payload may be **newer** than
  the flag, never older.
- The flag was never initialised. `flag=2652150544` in the first error is
  `mem_model::backing_value()` — the deterministic hash returned for unwritten
  addresses — which satisfied the `seen_flag < k` guard instantly on garbage.
  A direct collision between two deliberate decisions: the hash exists to remove
  the "X on first read" blind spot, and the sequence assumed memory starts at
  zero.

Both fixed in `cache_vseq_lib.sv`. Written up as [D-005](docs/DEBUG_LOG.md) with
the diagnosis path, which cost no waveform and no RTL reading — mismatch
direction plus the golden memory's silence identified the faulty component in two
observations.

**The useful generalisation: a checker that is too strong is a checker that is
wrong.** This one asserted a property the design never claimed and would have
failed on correct RTL forever.

**Re-run after the fix: 0 UVM errors**, no `[producer_consumer_vseq]` entries.
`stores` went 16 -> 17, the one added `flag_init` write, which confirms the
seeding actually executed. The message-passing ordering claim is now backed by a
passing run rather than by argument alone.

### Clean run, 2026-08-21: `upgrade_race_test` passes — 6 of 6 rounds

```
[CFG] cores=2 sets=16 ways=2 line=16B
[SB]  loads=12 stores=12 touched_words=6
      ReadShared=12 ReadUnique=6 CleanUnique=6 WriteBack=0
      state transitions=42  invariant sweeps=42
[COV] cg_core 59.40 | cg_bus 77.78 | cg_mesi 77.37
      cg_alloc 47.92 | cg_axil 66.67 | cg_share 83.33 | OVERALL 68.74 %
```

**`CleanUnique=6, ReadUnique=6` over six rounds is a perfect 1:1, and it is the
whole point of the test.** Each round has one winner that completes its upgrade
and one loser whose pending `CleanUnique` is invalidated before grant and must be
re-derived as a `ReadUnique`. The degradation path — the only race an atomic bus
does not remove — executed on **100 % of rounds**, with no data loss, no SWMR
violation and no assertion failure.

The README previously hedged that the overlap "cannot be forced with absolute
certainty but is reliable". Six for six is better than the claim.

**The transition count is exactly derivable and matches.** Per round: `I->E`
(first load), `E->S` and `I->S` (second load), `S->M` and `S->I` (the race),
`M->I` and `I->M` (the loser's `ReadUnique`). Seven per round x six rounds = 42,
which is what the scoreboard counted. A predicted number matching exactly is
worth more than a pass, because it means the mechanism is understood rather than
merely working.

**`cg_axil` at 66.67 % proves zero AXI writes occurred**, and that is correct
rather than a gap. `cp_dir` covered 1 of 2, `cp_beat` 4 of 4, `x_dir_beat` 4 of
8 -> (50 + 100 + 50)/3 = 66.67. No memory write happened all run because
`ReadUnique` hitting **M** hands the dirty line straight to the requester without
refreshing memory — exactly the behaviour documented under "Where dirty data
goes", now measured rather than asserted.

### Second geometry, 2026-08-21: 4-way / 8-set passes

`+define+CFG_NUM_WAYS=4 +define+CFG_NUM_SETS=8`, `eviction_test +num_txns=30`.
No source changes. 0 UVM errors, 0 assertion failures.

```
[CFG] cores=2 sets=8 ways=4 line=16B  mem_delay=[1:6]
[SB]  loads=28 stores=32 touched_words=26
      ReadShared=13 ReadUnique=12 CleanUnique=5 WriteBack=3
      state transitions=55  invariant sweeps=55
[COV] cg_core 87.50 | cg_bus 97.22 | cg_mesi 94.74
      cg_alloc 72.92 | cg_axil 100.00 | cg_share 100.00 | OVERALL 92.06 %
```

**This was the highest-risk outstanding item and the one the README most needed.**
The design-decisions section claimed that geometry is a verification variable,
that the same environment must pass at both widths, and that "only at 4 ways is
the tree actually a tree". None of that had been demonstrated. It now has: at
four ways the PLRU is two levels of decision over three bits per set rather than
a single LRU bit, and victim selection never once picked a dirty way without a
writeback.

**`WriteBack` fell from 14 to 3**, which is a real microarchitectural result
rather than a testbench artefact. A working set that thrashed a 2-way set largely
fits in a 4-way one, so conflict evictions — and therefore dirty writebacks —
become rare. Simulation time fell from 18.7 us to 10.7 us for the same 60
accesses, because each writeback carries AXI write traffic.

**`cg_alloc` fell 84.38 -> 72.92 %, and that is arithmetic, not regression.**
Written up as [O-009](docs/DEBUG_LOG.md): `cp_way` went 2 bins to 4 and
`x_victim_way` 6 to 12, while allocation events *decreased* with the writeback
count. More bins to fill, fewer events to fill them with. The wider lesson is
that coverage percentages are not comparable across configurations at all, so a
figure is only meaningful quoted alongside the `[CFG]` line that produced it.

### Bug injection complete, 2026-08-21: 5 of 5 detected

| Bug | Detected by | Time | Exit |
|---|---|---|---|
| `BUG_1` | `cg_mesi` illegal bin `m_to_e` | 1.46 us | 1 |
| `BUG_5` | `cg_share` illegal bin `se` | 1.80 us | 1 |
| `BUG_4` | `cg_mesi` illegal bin `dirty_dropped` | 3.67 us | 1 |
| `BUG_3` | golden memory (`SB_DATA`, `SB_FINAL`) | 7.64 us | **0** |
| `BUG_2` | `cg_share` illegal bin `ms` | 7.68 us | 1 |

No single mechanism catches more than two. `cg_mesi` is blind to `BUG_2`,
`BUG_3` and `BUG_5`; `cg_share` is blind to `BUG_3`. The three checking
strategies are complements rather than alternatives, and the table is the
evidence for that instead of an assertion of it.

`BUG_4` log:

```
Error-[FCIBH] Illegal bin hit
  At time 3665000 ps, Illegal bin dirty_dropped of cross x_trans in covergroup
  cache_uvm_pkg::cache_coverage::cg_mesi got hit with sample values
  cp_old=MESI_M cp_new=MESI_M cp_tagc=0x1
Exit code expected: 0, received: 1
```

`cp_old=M`, `cp_new=M`, `cp_tagc=1` reads as: this way held a modified line and
now holds a *different* modified line, with no writeback in between.

**New observation ([O-008](docs/DEBUG_LOG.md)): the abort hides whichever
detector would have fired second.** `BUG_4` had three candidate detectors and
`cg_mesi` won on **statement order** inside `write_probe`, not on merit —
`cg_alloc` is sampled a few lines later on the same probe item and was never
reached, and the reconciliation phase never ran. Reported honestly as *one fired,
two reachable but unproven*, rather than claiming three independent detections.

**O-007 now holds across four bugs and is monotonic.** Path executions 17, 17,
14, 2 map to detection at 1.46, 1.80, 3.67, 7.68 us without exception. `BUG_3`
sits outside the ordering because a data checker cannot complain until the
corrupted value is *read back* — its path runs most often of all (32 stores) yet
it is among the slowest to detect. A covergroup samples the event; a scoreboard
waits for the consequence.

### Bug injection, 2026-08-21: `BUG_5` detected — negative prediction holds again

`+define+BUG_5`, `eviction_test +num_txns=30`.

```
Error-[FCIBH] Illegal bin hit
  At time 1795000 ps, Illegal bin se of cross x_pair in covergroup
  cache_uvm_pkg::cache_coverage::cg_share got hit with sample values
  cp_c0=MESI_S cp_c1=MESI_E
Exit code expected: 0, received: 1
```

Core 1 issued `ReadShared` for a line core 0 held, the interconnect correctly
reported `IsShared`, and core 1 installed **E** regardless — leaving core 0 in
**S** beside an exclusive owner. `cg_mesi` saw nothing, as predicted: `I->E` is a
legal transition.

**The sharpest point in the whole bug set.** `bus_sva` and `cg_bus` could not
have caught this either, because the interconnect is behaving *perfectly* — it
snooped, aggregated and reported `IsShared` correctly. Bus traffic under `BUG_5`
is indistinguishable from a clean run. The defect is entirely in how the
requester **consumes** a correct response, so only a check that inspects
resulting cache state can observe it.

With `BUG_2` this is the argument for `cg_share` made twice: two different
mutations, two different code paths, neither visible to the per-cache transition
check or to the bus check, both caught by looking at two caches at once.

Third data point for [O-007](docs/DEBUG_LOG.md), and it tightens the correlation.
`BUG_1` and `BUG_5` both sit on the `ReadShared` path (17 executions) and were
caught at 1.46 us and 1.80 us. `BUG_2` sits on the `CleanUnique` path (2
executions) and took 7.68 us. Execution frequency is the only variable.

### Bug injection, 2026-08-21: `BUG_2` detected — including the negative prediction

`+define+BUG_2`, `eviction_test +num_txns=30`.

```
Error-[FCIBH] Illegal bin hit
  At time 7675000 ps, Illegal bin ms of cross x_pair in covergroup
  cache_uvm_pkg::cache_coverage::cg_share got hit with sample values
  cp_c0=MESI_M cp_c1=MESI_S
Exit code expected: 0, received: 1
```

**The negative half of the prediction is the valuable half.** `cg_mesi` sits at
98.95 % on this stimulus and saw nothing, because there is no transition to see:
the sharer's state is unchanged and the probe monitor only emits on change.
Detection required reading *both* caches at one instant, which is what `cg_share`
does via `state_of()` on every probe event. A per-cache view of a coherence
protocol is structurally insufficient — demonstrated, not argued.

**Detection latency is 5x that of `BUG_1`.** Written up as
[O-007](docs/DEBUG_LOG.md): on the clean run `eviction_test` produced
`ReadShared=17` but `CleanUnique=2`, so the mutated path executes twice in the
whole test. `BUG_1` sits on a 17-times path and was caught at 1.46 us; `BUG_2`
sits on a 2-times path and was caught at 7.68 us.

The hazard that follows is now measurable rather than hypothetical: clean
`smoke_test` reported `CleanUnique=0 WriteBack=0`, so `BUG_2` and `BUG_4` are
**provably** undetectable under it. A bug-injection matrix has to be read as
bug x test, never bug alone.

### Bug injection, 2026-08-21: `BUG_3` detected — prediction confirmed exactly

`+define+BUG_3`, `eviction_test +num_txns=30`. Every element of the prediction
written down before the run held: no illegal bin, no assertion failure, run to
completion, full coverage table, **exit code 0**, detection by golden memory
alone.

```
UVM_ERROR [SB_DATA]  load mismatch: c0 LD addr=0x0000022c rdata=0x1d4972af expected=0x9d4972af
UVM_ERROR [SB_FINAL] addr 0x00000024 expected=0xa7671c07 actual=0xa7676b07
UVM_ERROR : 11        [SB_DATA] 5    [SB_FINAL] 6
$finish at 18655000
```

**The coverage table came back byte-identical to the clean run** — 94.53 %
overall, same figure in all six groups, same sim time, same traffic counters.
Eleven data corruptions were present and the coverage model registered nothing.
Written up as [O-006](docs/DEBUG_LOG.md): this is the concrete refutation of
"coverage closed, therefore done". The bug changes no state, no transition, no
bus op and no allocation, so there is no event for a covergroup to sample.
Adding bins would not help.

Three further readings off the log:

- **The mismatch pattern identifies the bug class.** Disagreements are
  byte-granular and the agreeing bytes are exactly those the store had enabled.
  A control-path defect would have corrupted whole words or fetched wrong lines.
- **Both cores observed the same wrong value** at `0x328`, 2.2 us apart.
  Coherence is working perfectly and faithfully propagating corruption — it
  guarantees agreement between caches, not correctness of what they agree on.
- **Four of the six `SB_FINAL` mismatches were at addresses no load ever read.**
  End-of-test reconciliation is the only reason they were reported.

Together with `BUG_1` this completes the O-005 argument: `BUG_1` exits 1 with
nothing in the UVM summary, `BUG_3` exits 0 with eleven errors in it. Neither
signal is sufficient alone.

### Bug injection, 2026-08-21: `BUG_1` detected

`+define+BUG_1` in Compile Options, `eviction_test +num_txns=30`.

```
Error-[FCIBH] Illegal bin hit
  At time 1455000 ps, Illegal bin m_to_e of cross x_trans in covergroup
  cache_uvm_pkg::cache_coverage::cg_mesi got hit with sample values
  cp_old=MESI_M cp_new=MESI_E cp_tagc=0x0
Exit code expected: 0, received: 1
```

The environment caught the bug it was built to catch, and the message names the
defect rather than a symptom: a line moved **M** to **E** with no tag change,
which is the injected mutation stated back verbatim. Detected 1.46 us into a run
that takes 18.7 us clean, so within the first 8 %.

**New observation ([O-005](docs/DEBUG_LOG.md)): the three reporting mechanisms
fail in three different ways.** A `uvm_error` reaches the UVM summary but exits
0; an SVA failure reaches neither and exits 0; an illegal bin reaches neither,
aborts the run, and exits 1. Only the last is safely scriptable by exit code, and
only the first by grepping `UVM_ERROR`. The `bugs` target was already written to
count assertion and illegal-bin hits separately — that now looks like the right
call for a reason only visible once a bug was actually injected.

Side effect: the abort truncates the run, so the SWMR check that would
independently have caught `BUG_1` never runs. The redundancy is real but this
run does not demonstrate it.

**Nuance: `m_to_e` only fires when the snooped line was M.** Had it been **E** or
**S**, the transition would have been `E→E` — no state change, so no probe event
and no sample at all — or `S→E`, and detection would have fallen to `cg_share`
and the SWMR sweep. The same injected bug is caught by different checkers
depending on workload. `eviction_test` is 50–90 % stores, which is why the dirty
case dominated and `cg_mesi` won the race.

**Predictions recorded for `BUG_2`–`BUG_5` before running them**, so the
comparison afterwards is a test rather than a rationalisation. Written up per bug
in the README with the exact RTL mutation, the stimulus each one requires, and
which checker should fire and why:

- `BUG_2` and `BUG_5` should **not** be caught by `cg_mesi`. In both cases the
  affected cache undergoes no illegal per-cache transition — `BUG_2` produces no
  transition at all in the sharer, and `I→E` in `BUG_5` is perfectly legal. They
  are visible only as cross-cache *pair* properties, which is the argument for
  `cg_share` and the SWMR sweep existing as separate mechanisms.
- `BUG_3` should violate no protocol rule whatsoever. Expect a scoreboard
  `UVM_ERROR`, a run to completion, a full coverage table, and **exit code 0** —
  the case a naive `exit != 0` regression script reports as a pass.
- `BUG_4` requires a capacity eviction of a dirty line, so it is undetectable
  under `smoke_test` or `pingpong_test` regardless of checker quality.

**Recorded the general point that a clean bug-injection run has two meanings:**
the checkers cannot see that defect class (a real hole), or the stimulus never
created the conditions the defect needs (a test-selection mistake). Only the
first is a verification problem, and conflating them would make the whole
exercise meaningless.

### Clean run, 2026-08-21: `eviction_test` passes — best run so far

First test to produce writebacks. 0 UVM errors, 0 assertion failures.

```
UVM_ERROR : 0    UVM_FATAL : 0    (no SVA failures)
[SB]  loads=28 stores=32 touched_words=18
      ReadShared=17 ReadUnique=19 CleanUnique=2 WriteBack=14
      state transitions=68  invariant sweeps=68
[COV] cg_core 86.61 | cg_bus 97.22 | cg_mesi 98.95
      cg_alloc 84.38 | cg_axil 100.00 | cg_share 100.00 | OVERALL 94.53 %
```

**`WriteBack=14`.** The dirty-eviction path had never executed in any previous
run. The end-of-test memory reconciliation now has something to reconcile, and it
passed — no dirty line was dropped across fourteen evictions.

**`cg_share` 100 %.** All eight legal two-cache state pairs observed, and none of
the eight `illegal_bins` hit. The SWMR enumeration is fully exercised and clean;
that covergroup is done.

**`cg_alloc` 84.38 % decomposes exactly.** The group averages six items:
`cp_victim` (3 bins), `cp_way` (2), `cp_set` (16), `cp_core` (2), `x_victim_way`
(6), `x_way_core` (4). `(100x5 + 6.25)/6 = 84.375`. So every victim state, both
ways, both cores and both crosses are fully covered, and the only gap is
`cp_set` at 1 of 16 — precisely what a sequence that pins one set should produce.
The `illegal_bins dirty` was never hit, which is the RTL property that a dirty
victim always leaves through a writeback rather than being overwritten in place.

Simulation time jumped to 18.7 us from 7.1 us for the same 60 accesses, because
every writeback adds an AXI write burst the other tests never generate.

### Clean run, 2026-08-21: `pingpong_test` passes

Both cores hammering one word, 30 transactions each. 0 UVM errors, 0 assertion
failures.

```
UVM_ERROR : 0    UVM_FATAL : 0    (no SVA failures)
[SB]  loads=31 stores=29 touched_words=1
      ReadShared=11 ReadUnique=14 CleanUnique=11 WriteBack=0
      state transitions=71  invariant sweeps=71
[COV] cg_core 68.27 | cg_bus 82.41 | cg_mesi 77.37
      cg_alloc 42.71 | cg_axil 100.00 | cg_share 75.00 | OVERALL 74.29 %
```

`touched_words=1` and `WriteBack=0` are both correct and both predicted: one word
is one line, and a single line in a 2-way set never evicts. 71 transitions over
60 accesses is ownership migrating on more than one access in two — the intended
behaviour of this test.

**Finding: coverage went *down* in three groups despite 6x the transactions.**

| Group | `mesi_walk` (10 accesses) | `pingpong` (60 accesses) |
|---|---|---|
| `cg_bus` | 82.87 | 82.41 |
| `cg_mesi` | 80.53 | 77.37 |
| `cg_share` | 87.50 | 75.00 |
| `cg_core` | 56.73 | 68.27 |

This is the concrete demonstration that **stimulus volume is not coverage**. A
single line hammered 60 times cannot reach bins that need three lines in
different states, however long it runs; ten directed accesses can. Only `cg_core`
rose, because it samples address and byte-enable variety, which is the one thing
more random traffic actually provides.

It also means **no single run's number is meaningful**. The per-run figures have
been recorded as floors throughout, and merging is the only thing that turns them
into a closure claim — which is why it sits at the top of the future extensions
rather than in the middle.

**Second confirmation of D-004.** `pingpong_test` uses one address, so the tag
never changes for the whole run; under the old gate `cg_alloc` would have read
0.00 % here too. It reports 42.71 %, credited entirely through the
`old_state == MESI_I` path. The fix is validated on a second, independent test.

### Clean run, 2026-08-21: `mesi_walk_test` passes

All ten MESI transitions walked, 0 UVM errors, 0 assertion failures.
`CleanUnique=2` is the first time the upgrade path has executed at all.

```
UVM_ERROR : 0    UVM_FATAL : 0    (no SVA failures)
[mesi_walk_vseq] walked I->E E->M M->S I->S S->M S->I M->I E->S E->I I->M
[SB]  loads=5 stores=5 touched_words=3
      ReadShared=5 ReadUnique=2 CleanUnique=2 WriteBack=0
      state transitions=16  invariant sweeps=16
[COV] cg_core 56.73 | cg_bus 82.87 | cg_mesi 80.53
      cg_alloc 44.79 | cg_axil 100.00 | cg_share 87.50 | OVERALL 75.40 %
```

`cg_bus` 50.93 -> 82.87 and `cg_mesi` 64.21 -> 80.53: the directed walk is doing
exactly its job. `cg_core` fell 71.01 -> 56.73, which is expected — ten fixed
accesses touch fewer address and byte-enable combinations than random traffic.
That drop is the argument for cross-run coverage merging, already logged as a
future extension.

**`cg_alloc` first reported 0.00 %, which was a bug in the coverage model rather
than a coverage gap** — see [D-004](docs/DEBUG_LOG.md). Found by reading a number
that contradicted another number in the same run. The figures above are the
post-fix re-run; every group except `cg_alloc` was unchanged to two decimals.

### Clean run, 2026-08-21: `smoke_test` passes

Same seed as the failing run, with the D-003 gate applied. Zero assertion
output; scoreboard and coverage figures identical to before, confirming the fix
changed the protocol violation and nothing else.

```
UVM_ERROR : 0    UVM_FATAL : 0    (no SVA failures)
[SB]  loads=7 stores=3 touched_words=10
      ReadShared=7 ReadUnique=3 CleanUnique=0 WriteBack=0
[COV] OVERALL 65.34 %
```

Still unproven: eleven of twelve tests, both directed sequences, all five
injected bugs, the 4-way geometry, and any multi-seed behaviour.

---

## Architecture

- 2 x `l1_cache`, parameterised WAYS/SETS/LINE/CORES, write-back write-allocate,
  blocking (one outstanding miss), tree-PLRU with invalid ways preferred.
- MESI over an **atomic** snoop bus — grant held across snoop, memory access and
  response, so no cache is ever snooped while it owns the bus. No transient states.
- Three protocol boundaries, deliberately different:
  - core to L1: OBI-style `req`/`gnt`/`rvalid`
  - L1 to L1: simplified **ACE** (`ReadShared`/`ReadUnique`/`CleanUnique`/`WriteBack`,
    `IsShared`/`PassDirty`). ACE-inspired, **not** ACE-compliant.
  - interconnect to memory: real **AXI4-Lite**, `LINE_WORDS` single-beat transactions

---

## Key decisions

| Decision | Reasoning |
|---|---|
| Atomic bus, no transient states | Removes ~80% of MESI difficulty. Deliberate scoping; split-transaction is the stated next step. |
| ACE vocabulary, not AXI4-Lite, for coherence | AXI4-Lite structurally cannot carry coherence — no AC/CR/CD channels, no line-state signalling. |
| OBI on the core side | Real cores do not use AXI to their L1. AXI there buys complexity with no coverage. |
| Geometry via `+define+`, not module parameters | SystemVerilog packages cannot be parameterised, and the address field widths live in one. |
| 512 B per cache default | Absurdly small on purpose: conflict misses and evictions become common under random stimulus. |
| Whitebox probe into tag/state arrays | SWMR is a statement about *state*; it cannot be checked from the core interfaces at all. |
| Hierarchical probe wiring, not `bind` | Portability, since the toolchain was unconfirmed. `bind` is used for the SVA modules. |
| Golden memory ordered by monitor completion | Coherence already serialises same-address access; an order-reconstruction engine would be more code and more places to be wrong. |
| Coverage printed by the testbench | Target flow has no coverage database or merge. Tool-independent. |
| Forbidden MESI pairs as `illegal_bins` | Turns the coverage model into a checker. |
| Single UVM package (not per-agent) | Deferred until after bring-up; per-agent packages are the industry norm and the known gap. |
| `verif/` layout, not `uvm/` | Matches OpenHW/lowRISC. Never name a directory after the methodology. |

Every decision above is also marked in the source with a `DECISION:` comment —
`grep -rn "DECISION:" rtl/ verif/`.

---

## What is built

**RTL** (`rtl/`, 8 files) — package, 4 interfaces, `l1_cache`, `coherence_bus`, `cache_top`.

**Assertions** (`verif/sva/`, 4 files) — `cache_sva` bound per cache, plus
interconnect and AXI4-Lite protocol checkers. Key property `a_grant_excludes_snoop`
proves the assumption the whole no-transient-state design rests on.

**UVM** (`verif/`, 30 files)
- Agents: core (OBI, active), axil (AXI4-Lite slave + memory model), bus (passive), probe (whitebox)
- `coherence_scoreboard` — 6 independent checks: golden memory, MESI transition
  legality, SWMR invariant, sharer data agreement, bus-level consistency,
  end-of-test memory reconciliation
- `cache_coverage` — `cg_core`, `cg_bus`, `cg_mesi`, `cg_share`, `cg_alloc`, `cg_axil`
- 7 core sequences, 11 virtual sequences, 12 tests

**Directed vs constrained-random:** 8 CR virtual sequences, 3 directed
(`mesi_walk_vseq` walks all 10 legal MESI transitions so `cg_mesi` closes by
construction; `upgrade_race_vseq` forces the CleanUnique-to-ReadUnique
degradation; `producer_consumer_vseq` is a message-passing litmus test).

**Bug injection** — 5 RTL mutations behind `+define+BUG_n`. Every one must make
the regression fail; a clean run means the checkers are blind to it.

---

## Open risks

| Risk | Impact | Mitigation |
|---|---|---|
| Questa Starter may not licence classes/covergroups/SVA | Blocks everything | `make check-sv` decides in 5 min. Fallback: Questa for RTL waveform debug, EDA Playground for UVM |
| Interface array as a module port (`cache_top`) | Compile error | Flatten to explicit ports, or move generate into `tb_top` |
| `bind` target scope | Elaboration error | `-mfcu` already set for Questa; else instantiate directly |
| Cross `binsof ... intersect` support | Compile error | Move `illegal_bins` logic into `write_probe` as explicit checks |
| Hierarchical probe refs | Elaboration error | Verify generate label `g_cache` / instance `u_cache` |

Nothing has been compiled. Expect the first `make check-sv` / `questa-compile`
to surface issues; that is normal, not a setback.

---

## Bring-up log

Filled in as each step is attempted. Steps 0–4 are the local Questa machine;
step 5 onward is EDA Playground, because Questa Starter will not simulate
class-based verification code.

| # | Step | Command | Result |
|---|---|---|---|
| 0 | Tools visible | `vsim -version` | **OK** — Questa Altera Starter FPGA Edition-64, 2025.2 |
| 1a | Probe compiles | `vlog -sv tool_check.sv` | **PASS** — 0 errors, 0 warnings |
| 1b | Probe simulates | `vsim -c tool_check` | **BLOCKED** — no `svverification` licence |
| 2 | UVM capability | `vsim -c tool_check_uvm` | blocked by the same licence |
| 3 | Compile whole design | `vlog ... -f braytcache.f` | **PASS** — 0 errors, 0 warnings, 40 files |
| 4 | Elaborate | `vopt +acc=rn -L mtiUvm tb_top -o tb_opt` | **PASS** — 0 errors |
| 5 | Flatten for Playground | `python sim/bundle_playground.py` | **OK** — 21 `` `include ``s expanded into two panes |
| 6 | Compile + elaborate + link | VCS X-2025.06-SP1, UVM 1.2 | **PASS** — 0 errors |
| 7 | `smoke_test` | `+UVM_TESTNAME=smoke_test +num_txns=5` | **PASS** after D-001, D-002, D-003 |
| 8 | `mesi_walk_test` | directed, no `+num_txns` | **PASS** — all ten transitions; exposed D-004 |
| 9 | `pingpong_test` | `+num_txns=30` | **PASS** — 71 ownership migrations |
| 10 | `eviction_test` | `+num_txns=30` | **PASS** — 14 writebacks, 94.53 % coverage |
| 11 | `BUG_1` injection | `+define+BUG_1` | **DETECTED** — `cg_mesi` illegal bin at 1.46 us, exit 1 |
| 12 | `BUG_3` injection | `+define+BUG_3` | **DETECTED** — 11 scoreboard errors, exit 0 |
| 13 | `BUG_2` injection | `+define+BUG_2` | **DETECTED** — `cg_share` illegal bin at 7.68 us, exit 1 |
| 14 | `BUG_5` injection | `+define+BUG_5` | **DETECTED** — `cg_share` illegal bin at 1.80 us, exit 1 |
| 15 | `BUG_4` injection | `+define+BUG_4` | **DETECTED** — `cg_mesi` illegal bin at 3.67 us, exit 1 |
| 16 | Second geometry | `+define+CFG_NUM_WAYS=4 +define+CFG_NUM_SETS=8` | **PASS** — `eviction_test`, 0 errors |
| 17 | `upgrade_race_test` | directed, no `+num_txns` | **PASS** — 6 of 6 rounds hit the degradation |
| 18 | `producer_consumer_test` | directed, no `+num_txns` | **PASS** — after the D-005 sequence fix |
| 19 | `false_sharing_test` | `+num_txns=30` | **PASS** — 4 words of one line, 0 errors |
| 20 | `store_streak_test` | no `+num_txns` | **PASS** — 90 stores, 5 bus transactions |
| 21 | `read_mostly_test` | `+num_txns=30` | **PASS** — 60 loads, zero ownership acquired |
| 22 | `shared_region_test` | `+num_txns=30` | **PASS** — `cg_share` closed at 100 % |
| 23 | `random_test` | no `+num_txns` | **PASS** — `cg_alloc` closed at 100 %, 95.80 % overall |
| 24 | `regression_test` | no `+num_txns` | **PASS** — **98.92 % overall**, best single run |
| 25 | Multi-seed regression | | blocked — Playground has no runner and caps CPU time |

### Milestone, 2026-08-21: compiles and elaborates clean

Questa Altera Starter FPGA Edition 2025.2, UVM 1.1d built-in.

```
vlog ... -f braytcache.f     Errors: 0, Warnings: 0
vopt ... tb_top -o tb_opt    Errors: 0, Warnings: 1   (vopt-10908, +acc side effect)
```

**All four structural risks logged on 2026-08-09 are retired**, each confirmed by
a specific line of vopt output:

| Risk | Evidence |
|---|---|
| Interface array as a module port | `-- Loading module cache_top` |
| `bind` elaborating at all | `-- Loading module cache_sva`, `-- Optimizing module cache_sva(fast)` |
| Cross `binsof ... intersect` | `cache_uvm_pkg` compiled clean |
| Hierarchical probe references | `-- Optimizing module tb_top(fast)` |

Also confirmed: two parameterized `l1_cache` variants (`fast`, `fast__1`) from
the generate loop, and all four interfaces elaborated.

**This proves the code is structurally valid, not functionally correct.** No
simulation has run. The scoreboard, SWMR checker, coverage model and MESI logic
are completely unexercised.

**Fixed: `bind` at compilation-unit scope.** Questa warned (vlog-2650) that a
$unit-scope bind needs `-cuname` to be elaborated at all. A bind that does not
elaborate deletes every per-cache assertion *without failing*, which is the worst
kind of silent hole. Moved into `tb_top` module scope — portable, no tool flags.
`verif/sva/sva_bind.sv` was removed from the filelist, the Playground bundler and
the docs, and the file itself is deleted.

**UVM is 1.1d, not 1.2.** Questa Altera Starter ships `mtiUvm` built on uvm-1.1d
and auto-links it. Everything compiled against it unchanged, so no code change is
needed — only the docs claimed 1.2.

**Decision: no shell wrapper during local bring-up.** Work happens in the Questa
GUI Transcript, which is Tcl. The local flow is four commands: `cd`,
`vlib work`, `vlog -f braytcache.f`, `vopt`. A `sim/run.sh` bash driver was
written and then removed as unnecessary — the Transcript is the interface in
use, and the batch commands it existed for are licence-blocked anyway.
`sim/Makefile` remains for environments that have GNU Make.

### Finding, 2026-08-21: local simulation is licence-blocked

```
** Error: Failure to checkout svverification license feature.
** Error: (vsim-1) Unable to checkout verification license - required for
   testbench features (randomize, randcase, randsequence, covergroup).
```

Questa **Starter** compiles class-based SystemVerilog but is not licensed to
simulate it. Confirms the risk logged on 2026-08-09. Not a code defect.

**What still works locally:** `vlog`. The whole testbench can be compile-checked
on this machine, which catches syntax and structural errors across all 40 files.
Only `vsim` is blocked.

**Useful side effect:** `tool_check.sv` compiled with 0 errors/0 warnings, and it
deliberately exercises the constructs that were flagged as unverifiable —
classes, `rand` with `soft` constraints, a covergroup cross carrying
`illegal_bins` and `ignore_bins`, and `default clocking` + `assert property`.
That retires the "cross `binsof` support" risk.

**Options for actually running it:**
1. A full Questa/VCS/Xcelium licence (university or employer EDA infrastructure)
2. EDA Playground (Aldec Riviera-PRO) — free, includes the verification features
3. Keep Questa for RTL waveform debug only

**Decision, 2026-08-21: option 2.** No licence obtainable. Simulation moves to
EDA Playground; Questa stays useful for `vlog`/`vopt` structural checking, which
is not nothing — it caught the compilation-unit bind problem.

Playground needs the tree flattened into two panes because it cannot resolve
`+incdir`, so the 21 `` `include `` directives in `cache_uvm_pkg.sv` have to be
expanded inline. That is what `sim/bundle_playground.py` produces. Moving the
bind into `tb_top` module scope also matters here: Playground compiles the
Design and Testbench panes separately, and a `$unit`-scope bind would likely
have been dropped.

Settings: sign in (anonymous cannot use commercial simulators), Aldec
Riviera-PRO, UVM 1.2, `+UVM_TESTNAME=smoke_test +num_txns=5`. No `+define+`
needed — `cache_pkg.sv` defaults are already the 2-way/16-set/16-byte/2-core
configuration.

Bundle generated clean on 2026-08-21: `design.sv` 1195 lines (RTL + 3 SVA
modules), `testbench.sv` 2561 lines (`cache_uvm_pkg` with all 21 includes
expanded, plus `tb_top`). No unresolved includes. Design pane carries no UVM
dependency, so it compiles first without needing the UVM library.

Simulator: **Synopsys VCS** on Playground (available once the account is
verified) rather than Riviera-PRO — same effort, more recognisable, and it means
the project builds under Questa and simulates under VCS, which is a portability
claim worth having.

All Playground checkboxes off for bring-up. Two become useful later: *Open
EPWave after run* paired with `+dump` for waveform debug, and *Use run.bash* to
loop several `+UVM_TESTNAME` values in one session, since Playground has no
regression runner.

### First simulation attempt, 2026-08-21 (VCS X-2025.06, UVM 1.2)

Compiled, elaborated, linked and started UVM. Reached `build_phase` and printed
the config banner, then:

```
UVM_FATAL [RUNPHSTIME] The run phase must start at time 0, current time is 1000.
```

Cause: `tb_top` had `#1` before `run_test()`. UVM 1.2 forbids consuming any
simulation time before `run_test()`; UVM 1.1d (Questa) does not enforce it, which
is why the local build never caught it.

The delay was not gratuitous — `uvm_root::run_test()` forks the phase runner
`join_none` then does its own `#0`, so without a yield `build_phase` can race the
generate-scoped `config_db` sets and fail on a missing virtual interface. Fixed
with `#0`, which yields to those blocks while leaving `$time` at 0.

Two benign notes from VCS, no action:
- `SVA-LDRF` on `a_bus_progress`' `##[1:500]` window — compile-time optimisation
  note, may affect runtime.
- `INTFDV` on `$dumpvars(0, tb_top)` — selective VCD dumping of interfaces is
  unsupported. Only relevant when `+dump` is used.

### First end-to-end run, 2026-08-21: `smoke_test` executes

```
UVM_ERROR : 0    UVM_FATAL : 0
[SB]  loads=7 stores=3 touched_words=10
      ReadShared=7 ReadUnique=3 CleanUnique=0 WriteBack=0
      state transitions=10  invariant sweeps=10
[COV] cg_core 71.01 | cg_bus 50.93 | cg_mesi 64.21
      cg_alloc 72.57 | cg_axil 66.67 | cg_share 66.67 | OVERALL 65.34 %
```

Every mechanism ran: golden-memory checking, the SWMR sweep, the probe
transition stream, and all six covergroups.

**Caveat: `UVM_ERROR : 0` is misleading.** Two assertions failed on every bus
transaction, and **SVA failures are reported by the simulator, not UVM**, so they
never reach the UVM summary. Any pass/fail script that greps only `UVM_ERROR`
will report a false pass — which is exactly why the `bugs` target was already
extended to count assertion and illegal-bin hits separately.

**Bug found and fixed: `snoop_ack` lingered one cycle.**

```
a_ack_qualified:        ((ack_v & (~sel_v)) == '0)
a_snoop_ack_qualified:  (snoop_valid && snoop_sel)
```

`sn_ack_q` is registered and only clears the cycle *after* `sn_active` falls, so
when the interconnect left `B_SNOOP` the ack stayed asserted while unselected.
Functionally benign — acks are only sampled during `B_SNOOP`, and there is a
two-cycle gap before the next one — but a real protocol imprecision. Fixed by
gating the output (`sn_ack_q && sn_active`) rather than weakening the assertion.

The assertions earned their place on the first run.

`CleanUnique=0` and `WriteBack=0` are expected at 5 transactions per core:
upgrades need a store to an `S` line and writebacks need a dirty eviction.
Neither is reachable in that little traffic.

### Note: stale copy on the run machine

`vlog -f braytcache.f` failed with ENOENT because the run machine still holds a
copy taken before the 2026-08-20 rename, where the filelist is `cachebrayt.f`.
RTL and verification sources are unaffected — they have not changed since
2026-08-09 — so compile results from the old filelist are still valid.

Manual copying has no staleness detection. Re-copy the whole directory whenever
the authoring side changes anything under `sim/`, and prefer deleting the old
copy first so renamed files do not linger alongside their replacements.

Step 1 is the decision point: a stage 1 or 2 failure means Questa Starter does
not licence class-based verification or covergroups, and the UVM work moves to
EDA Playground. That is a licence boundary, not a defect.

---

## Next steps

1. Copy `braytcache/` to the run machine by hand — nothing needs building first
2. Run machine: `make check-sv`, then `make check-uvm`
3. `make questa-compile` — syntax and elaboration only
4. `make questa TEST=smoke_test PLUS=+num_txns=5`
5. Work up: `random_test`, `pingpong_test`, `producer_consumer_test`, `mesi_walk_test`
6. `make bugs` — every run must fail
7. `make regress` — all tests x all seeds
8. `make questa WAYS=4 SETS=8` — second geometry
9. Fill the README Results table, then coverage closure to 100%

---

## Session log

### 2026-08-08 — build
Architecture agreed. Wrote all RTL, SVA, UVM environment, build flow and setup
doc from scratch. Nothing compiled (authoring machine is edit-only by design).

### 2026-08-09 — review, restructure, hardening
- Full pre-compile audit. Found and fixed 8 defects, three functional:
  `BUG_4` injection was broken (stray bus request corrupted the following
  transaction); both drivers could mis-detect their first handshake because
  reset deasserts via NBA leaving them off the clocking event; the AXI monitor's
  analysis port was connected to nothing.
- Restructured to `rtl/` + `verif/{agents,env/seq_lib,tests,sva,tb}`.
- Section-level comments added throughout with `DECISION:` markers.
- Added `mesi_walk_vseq` and `upgrade_race_vseq` — the directed/CR split was
  9-to-1 before this.
- Second audit found 3 more: the UVM capability probe had a `config_db` scope
  bug that would have falsely reported a broken install; `make regress`
  recompiled the design 60 times; `make bugs` could report a false pass because
  `illegal_bins` hits are not UVM errors.
- Added `tool_check.sv` / `tool_check_uvm.sv` capability probes after learning
  the target is Questa-Intel FPGA **Starter** Edition, whose licence may exclude
  class-based verification entirely.

### 2026-08-20 — repo setup, workflow settled
- Project moved into a git repo (`braytcache`), cloned from GitHub.
- Added `.gitignore` — simulator build products were about to pollute the repo.
- Renamed `cachebrayt` to `braytcache` throughout: 9 references plus the filelist.
- Added the run-machine requirements checklist to `docs/SETUP.md`.
- **Workflow fixed: the authoring machine compiles and runs nothing.** Transfer
  to the run machine is a manual directory copy, one direction only. Git is
  available for history but is not the transfer mechanism.
- Added the bring-up log above. Step 1 (`check-sv`) is the gate that decides
  whether the UVM environment can run locally at all.
- `make --version` failed on the run machine: **Git Bash does not ship GNU Make.**
  Added `sim/run.sh`, a plain-bash driver with the same commands and flags.
  *Removed again on 2026-08-21* — the Questa GUI Transcript turned out to be the
  working interface, it cannot run bash, and the batch commands `run.sh` existed
  for are licence-blocked. The Makefile/`run.sh` duplication resolved itself.
- Rewrote the head of `docs/SETUP.md`: "this machine" was ambiguous depending on
  which machine you opened the file on. Now names the two roles explicitly and
  states that every command belongs in a bash shell on the run machine.
- Added "VS Code and Questa are doing different jobs" to `docs/SETUP.md` after
  confusion over what Questa is even for. Documents both drive methods: the
  Questa GUI Transcript (Tcl, cannot run a bash script) and a bash shell (can).
- Clarified that **nothing needs configuring between VS Code and Questa** — they
  are unrelated programs sharing only a directory. Getting Questa "to see the
  project" is one `cd` in its Transcript pane, nothing more.
- Run machine path: `C:/Users/Brayton Yu/braytprojects/cachebrayt/braytcache`.
  **The space in "Brayton Yu" must be quoted** — `{...}` in the Questa Transcript
  (Tcl), `"..."` in bash. Commands run from the `sim/` subdirectory.
- README "Running it" rewritten around the real toolchain: Questa–Intel/Altera
  FPGA Starter Edition, why it was chosen over Verilator/Icarus/XSim, why the
  free tier's uncertain licence drove the two capability probes, and why GNU Make
  is not assumed. Commands later reverted to `make` / raw Transcript calls when
  `run.sh` was removed.

### 2026-08-21 — first passing run, documentation
- Three tool-found bugs fixed and written up in `docs/DEBUG_LOG.md` (D-001 `bind`
  scope, D-002 `#1` before `run_test()`, D-003 ungated `snoop_ack`).
- `smoke_test` passes clean on VCS: 0 UVM errors, 0 assertion failures.
- README Results table populated with the compile/elaborate/`smoke_test` rows.
  Coverage rows deliberately left `_TBD_` — a single 10-transaction run reports
  65.34 % overall, which is a floor from one seed, not a closure figure.
- Rewrote the README **Tests** section. It was a bare comma-separated list of
  twelve names, which told a reader nothing about why twelve tests exist. It is
  now a table of *what each test exercises* and *what a failure would tell you*,
  ordered by how easy the resulting failure is to debug rather than by coverage.
  The second column is the point: a test list is only useful if it explains what
  a failure localises to. Several entries state properties that are invisible
  otherwise — `store_streak_test` checks that the silent paths stay **bus-silent**
  (an **M** hit that broadcasts is still functionally correct), `read_mostly_test`
  treats *unexpected* bus traffic as the signal, and `producer_consumer_test`
  checks ordering rather than coherence since its two lines are independently
  coherent.
- `mesi_walk_test` run: passes, all ten transitions walked, `CleanUnique` path
  executed for the first time.
- **D-004 found and fixed:** `cg_alloc` was gated on `tag_changed` as a proxy for
  "an allocation happened". The walk uses lines at `0x00`/`0x10`/`0x20`, which
  differ only in index — all tag `0` — and both the RTL tag array and the probe
  monitor's shadow reset to `0`, so every fill looked like no tag change and the
  covergroup never sampled. Gate now states the real predicate: a way is being
  installed with a line. Random stimulus had been hiding this since day one.
  Re-run confirms: `cg_alloc` 0.00 -> 44.79 %, OVERALL 67.94 -> 75.40 %, every
  other group and every scoreboard counter unchanged.
- README "Running it" gained a **The loop** subsection. The two tools were each
  documented, but the cycle joining them was not written down anywhere, and the
  re-paste rule (Design pane for `rtl/`+`sva/`, Testbench pane for everything
  else) had been carried in conversation rather than in the repo.
- Documented the actual `vcs` command Playground runs. It explains why errors
  cite `design.sv`/`testbench.sv` line numbers, why UVM is recompiled from
  source every run, and the Compile-Options-vs-Run-Options split that decides
  where `+define+BUG_n` goes versus `+UVM_TESTNAME`.
- `pingpong_test +num_txns=30` run: passes, 71 ownership migrations over 60
  accesses. `WriteBack=0` and `touched_words=1` both as predicted.
- **Coverage fell in three groups despite six times the stimulus.** Recorded as a
  finding rather than a curiosity: it is the evidence that volume is not
  coverage, and that per-run percentages are floors until they can be merged.
- `eviction_test +num_txns=30` run: passes, **14 writebacks**, 94.53 % overall.
  First execution of the dirty-eviction path and the end-of-test memory
  reconciliation. `cg_share` and `cg_axil` both closed at 100 %.
- README Results table populated with real coverage figures, labelled as a best
  single run rather than a closure claim.
- Rewrote the README **Tests** section again, this time as architectural prose
  rather than a table. The table answered "what breaks if this fails", which is
  operational; it did not answer *why the test exists*. Each entry now states the
  mechanism under stress and why that mechanism is a plausible place for a design
  to be wrong — e.g. false sharing is where coherence granularity and program
  granularity disagree, so it separates invalidation from data loss; the
  producer-consumer litmus separates *coherence* (per-line, guaranteed by MESI)
  from *consistency* (cross-line, guaranteed only by blocking caches on an atomic
  bus). Grouped into structural / coherence-pressure / directed / composite, with
  the stated organising principle being **attribution**: constrain stimulus until
  one mechanism dominates, so a failure implicates that mechanism.
- Each test entry now opens with a plain description of the stimulus before the
  architectural discussion. Previously an entry went straight into *why* without
  ever saying *what* — readable only if you already knew the sequence library.
- **Documented that coverage does not accumulate across runs.** Each Playground
  run is a fresh `simv`, covergroups are built in the coverage component's
  constructor, nothing is written to disk, so `get_inst_coverage()` reports one
  simulation only. Twelve tests run in sequence give twelve unrelated numbers,
  not a twelve-test figure. Worth stating explicitly because the numbers look
  cumulative when read down the progress log and are not.
- Noted that `+num_txns` is **per core**: `+num_txns=30` on two cores is sixty
  accesses. Confirmed against the logs — `pingpong_test +num_txns=30` reported
  `loads=31 stores=29`.
- **First bug-injection run.** `BUG_1` detected by the `cg_mesi` illegal bin
  `m_to_e`. Recorded in the README bug table with a Status column, and the
  misleading "then SWMR" phrasing corrected — the illegal bin aborts the run, so
  the SWMR backstop never actually executes.
- Added O-005 to the debug log: a table of which reporting mechanism reaches the
  UVM summary, which aborts, and which sets a non-zero exit code. They differ on
  all three axes, which decides how a regression script must be written.
- Expanded the README bug-injection section into a per-bug record: exact RTL
  mutation, why it breaks the protocol, the stimulus it requires, which checker
  should fire and why, and what the run should look like. `BUG_2`–`BUG_5`
  predictions are written down **before** those runs, so the later comparison is
  evidence rather than hindsight.
- `BUG_3` run: detected, prediction held in every particular. Added O-006 to the
  debug log — identical coverage between the clean and buggy runs, which is the
  evidence that a coverage percentage is not a correctness claim.
- `BUG_2` run: detected by `cg_share`, and `cg_mesi` saw nothing exactly as
  predicted. Added O-007 — detection latency tracks how often the mutated path
  executes, with the corollary that `smoke_test`'s `CleanUnique=0 WriteBack=0`
  makes `BUG_2` and `BUG_4` provably undetectable there.
- Corrected the stale bring-up log, which still ended at "needs a verification
  licence" and recorded none of the VCS work. Now 18 rows through bug injection.
- **README audit for explanatory depth.** The document was strong on *what* and
  on *why this choice over that one*, but thin on *why the mechanism works*, so
  five sections gained derivations rather than assertions. Nothing was removed.
  - **Why the bus is atomic** now explains what a transient state is and why one
    would otherwise be needed — the window between issuing `ReadUnique` and
    receiving the line, where a cache is in neither **I** nor **M** and must
    still answer a snoop. Names the `IM_AD` convention and states plainly that
    most of the real difficulty in MESI lives in states this design does not
    have.
  - **Where dirty data goes** now derives from one rule (only **M** may hold data
    memory lacks) instead of asserting two cases, and explains what MOESI's
    *Owned* state buys. Ties it to a measured result: `cg_axil` hits 100 % on
    runs with `WriteBack=0` because dirty interventions alone generate AXI
    writes.
  - **SWMR** is now defined as a property before being described as a check, with
    the observation that it constrains *state* rather than transactions — which
    is the actual justification for the whitebox probe existing.
  - **The illegal bins** now derives 8-of-16 in a full 4x4 table rather than
    asking the reader to accept the count.
  - **Sampling discipline** now explains the Active/NBA region argument that
    makes post-edge sampling race-free, and states the trade-off: the guarantee
    rests on an RTL coding convention and would break silently under a
    combinational driver.
- Audit caught a factual error in the new state-pair table: the `c0=S, c1=E` cell
  was labelled `es` when the source names it `se`. Verified every cell against
  `cache_coverage.sv` and corrected.
- `BUG_4` run: detected by `cg_mesi` at 3.67 us. **Bug-injection matrix complete,
  5 of 5.** Added O-008 on the abort masking secondary detectors, and extended
  O-007 to four bugs where detection latency is monotonic in path frequency.
- README gained a **Bug injection results** section with the per-mechanism
  breakdown. The distribution is the point: no mechanism catches more than two of
  the five, so the three checking strategies are complements, not alternatives.
- **4-way / 8-set geometry passes.** The parameterisation claims in the README
  were the project's largest unsupported assertion; they are now backed by a run.
  Added O-009 on coverage percentages being incomparable across configurations,
  prompted by `cg_alloc` dropping 84.38 -> 72.92 % for purely structural reasons.
- **`upgrade_race_test` passes with 6 of 6 rounds hitting the degradation path.**
  `CleanUnique=6, ReadUnique=6` is a perfect 1:1, the 42 transitions match a
  hand-derived 7-per-round prediction exactly, and `cg_axil=66.67 %` confirms
  zero AXI writes — which is the documented `ReadUnique`-hits-**M** behaviour
  showing up as a measurement. README section on the race updated from a hedged
  claim to a measured one.
- **Added a README section: "What the runs revealed".** The findings from passing
  runs were only in this file, which is a chronological work log — the wrong
  place for a reader asking "what did you learn about writebacks". Deliberately
  *not* a new document: a fourth file would fragment the material further, and
  these findings are the most interesting output of the project, so they belong
  in the shop window. One table of run → finding, then the cross-cutting lessons,
  linking to the debug log for depth.
- Added O-010: `store_streak_test` passed cleanly while disproving a README
  claim, detected only by reading the `[SB]` traffic counters on a green run.
  The generalisable habit recorded there — check the traffic profile matches
  what the test was written to produce, before moving on — is what led to
  `read_mostly_test`'s `ReadUnique=0 CleanUnique=0 WriteBack=0` being written
  down as a prediction in advance, which then held.