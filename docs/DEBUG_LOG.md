# Debug log

Every defect found while bringing braytcache up on real tools, in the order it
surfaced. Each entry records the symptom, how it was found, why the code was
wrong, the reasoning behind the fix, and what to take away from it.

Defects found by inspection before any tool ran are in
[PROGRESS.md](../PROGRESS.md) under the 2026-08-09 audit entries. This file
covers what the tools found.

---

## D-001 — `bind` at compilation-unit scope silently drops every cache assertion

| | |
|---|---|
| **Date** | 2026-08-21 |
| **Found by** | Questa `vlog`, first full compile of the filelist |
| **Severity** | High — silent loss of checking, nothing reports a failure |
| **Fixed in** | `verif/tb/tb_top.sv`, `verif/sva/sva_bind.sv` (deleted) |

### Symptom

```
** Warning: (vlog-2650) 'bind' found in compilation unit scope.
   Please use -mfcu -cuname to ensure that 'bind' gets elaborated.
```

A warning, not an error. The compile reported `Errors: 0`.

### Root cause

The per-cache assertion module was attached from its own file:

```systemverilog
// verif/sva/sva_bind.sv  -- compilation-unit ($unit) scope
bind l1_cache cache_sva u_cache_sva ( ... );
```

Compiled with `-mfcu`, all files share one compilation unit, and items declared
at `$unit` scope live in an implicit package. Questa will not necessarily
elaborate that package unless it is named with `-cuname` and passed to the
elaborator.

### Impact on the work

It blocked nothing. That is the problem.

The compile reported `Errors: 0` and everything proceeded normally. Had this
shipped, `cache_sva` would never have been instantiated and **all twelve
per-cache properties would have silently ceased to exist** — including
`a_grant_excludes_snoop`, which is the property validating the central
architectural claim of the whole design (that an atomic bus means a cache is
never snooped while it holds a grant). The regression would have stayed green
while verifying materially less than the README claimed.

The cost of missing it compounds: **D-003 below was found by exactly these
assertions.** Had the bind stayed broken, that defect would have run undetected
through every subsequent test, because the scoreboard is structurally incapable
of seeing it. One silent gap in the checker set hides the next bug.

### Root cause

The per-cache assertion module was attached from its own file:

```systemverilog
// verif/sva/sva_bind.sv  -- compilation-unit ($unit) scope
bind l1_cache cache_sva u_cache_sva ( ... );
```

Compiled with `-mfcu`, all files share one compilation unit, and items declared
at `$unit` scope live in an implicit package. Questa will not necessarily
elaborate that package unless it is named with `-cuname` and passed to the
elaborator.

### How the fix was reached

The warning was easy to skim past — zero errors, 40 files compiled, the obvious
reaction is to move on. What stopped that was asking what the message actually
means *for a checker specifically*: "may not get elaborated" applied to RTL is a
build failure you would notice immediately, but applied to an assertion module it
is a silent deletion. Warnings about checkers deserve a different threshold of
attention than warnings about logic.

The tool's own suggestion — add `-cuname` — was considered first and rejected on
three counts:

1. It is Questa-specific syntax, and the project was already heading toward EDA
   Playground, where the Design and Testbench panes are compiled separately and a
   `$unit`-scope bind would very likely be lost again.
2. It makes the presence of the assertions depend on a command-line flag. Anyone
   who later runs `vlog` by hand, or writes a new script, silently loses them.
3. It fixes the symptom on one tool rather than the underlying fragility.

A bind in **module** scope elaborates unconditionally, per LRM, on every
simulator with no flags. The assertions become structurally impossible to lose.
That is worth more than keeping the bind in a tidy separate file.

The remaining question was how to *prove* the fix worked, since `vlog` cannot
tell you — bind resolution happens at elaboration, not compilation. That is what
made running `vopt` locally worth doing even though `vsim` was licence-blocked.

### Fix

Moved the `bind` statement into `verif/tb/tb_top.sv` at module scope. Deleted
`verif/sva/sva_bind.sv` and removed it from `sim/braytcache.f` and
`sim/bundle_playground.py`.

### Confirmation

`vopt` afterwards reported:

```
-- Loading module cache_sva
-- Optimizing module cache_sva(fast)
```

Both lines are the proof the bind elaborates. `vlog` alone could never have
confirmed it — bind resolution happens at elaboration.

### Takeaway

A warning saying a *checker* "may not be elaborated" is a correctness problem,
not a style nit. After wiring up any bind, verify the bound module actually
appears in the elaboration log.

---

## D-002 — `#1` before `run_test()` fatals under UVM 1.2

| | |
|---|---|
| **Date** | 2026-08-21 |
| **Found by** | First simulation attempt — VCS X-2025.06, UVM 1.2, EDA Playground |
| **Severity** | Blocking — simulation stopped at time 0 |
| **Fixed in** | `verif/tb/tb_top.sv` |

### Symptom

```
UVM_FATAL [RUNPHSTIME] The run phase must start at time 0, current time is 1000.
No non-zero delays are allowed before run_test(), and pre-run user defined
phases may not consume simulation time before the start of the run phase.
```

### Impact on the work

Hard stop. The very first simulation attempt died at time 0, before a single
clock edge of the design ran. Nothing downstream — no scoreboard, no coverage,
no assertions — could be evaluated until it was resolved.

### Root cause

```systemverilog
initial begin
  uvm_config_db #(virtual bus_if)::set(null, "*", "bus_vif", bus_i);
  uvm_config_db #(virtual axil_if)::set(null, "*", "mem_vif", mem_i);
  #1;                 // <-- 1 ns of simulation time
  run_test();
end
```

UVM 1.2 forbids consuming any simulation time before `run_test()`.

### How the fix was reached

The immediate instinct is to delete the `#1` — the error message all but tells
you to. Resisting that was the whole of the work here, because the delay was
load-bearing and removing it trades one fatal for a worse, intermittent one.

The question worth asking before deleting anything is *why was this written in
the first place*. Tracing it back:

1. The per-core virtual interfaces are published from **generate-scoped**
   `initial` blocks. That is not stylistic — an interface array can only be
   indexed by an elaboration-time constant, so a plain `for` loop inside one
   `initial` block will not compile:

   ```systemverilog
   for (genvar i = 0; i < NUM_CORES; i++) begin : g_vif
     initial uvm_config_db #(virtual core_if)::set(
       null, "*", $sformatf("core_vif%0d", i), core_ifs[i]);
   end
   ```

2. That forces them into *separate* `initial` blocks from the one calling
   `run_test()`, and SystemVerilog defines no execution order between `initial`
   blocks.

3. Reading what `run_test()` actually does settles it: `uvm_root::run_test()`
   forks the phase runner with `join_none` and then performs its own `#0`. So the
   phase runner — and therefore `build_phase` — can be scheduled *before* those
   generate blocks have executed.

So deleting the delay would produce a `UVM_FATAL` on a missing virtual interface
instead, and worse, one whose appearance depends on the simulator's process
ordering. It might have passed on VCS and failed on Riviera, or passed for weeks
and failed once.

What was actually needed: a yield that **orders processes without advancing
time**. `#0` suspends into the Inactive region of the current time step, so every
other time-0 `initial` block runs to completion first, then this one resumes.
Confirmed against the UVM source that the check is on `$time`, which `#0` leaves
at zero.

### Why it was not caught locally

Questa bundles **UVM 1.1d**, which does not enforce the zero-time rule; the check
arrived in 1.2. The design compiled and elaborated clean locally with the bug
present.

### Fix

```systemverilog
#0;
run_test();
```

`#0` suspends the process into the Inactive region of the *current* time step.
Every other time-0 `initial` block completes first, then this one resumes — the
ordering guarantee that was needed — while `$time` never leaves 0, so UVM's check
passes.

### Takeaway

Two simulators with different UVM versions catch different bugs; running under
both is worth more than running either twice. And when you need ordering *within*
a time step, `#0` is the correct tool — `#1` is a different operation that
happens to also work.

---

## D-003 — `snoop_ack` asserted for one cycle while unselected

| | |
|---|---|
| **Date** | 2026-08-21 |
| **Found by** | Assertions, on the first end-to-end `smoke_test` run |
| **Severity** | Low functionally, real as a protocol violation |
| **Fixed in** | `rtl/l1_cache.sv` |

### Symptom

Two assertions failing on **every** bus transaction, alternating between caches:

```
tb_top.u_bus_sva.a_ack_qualified
    Offending '((ack_v & (~sel_v)) == '0)'
tb_top.dut.g_cache[0].u_cache.u_cache_sva.a_snoop_ack_qualified
    Offending '(snoop_valid && snoop_sel)'
```

Both state the same rule from different vantage points: a cache must not
acknowledge a snoop it was not selected for.

### Impact on the work

The test *reported* a pass. `UVM_ERROR : 0`, scoreboard clean, all six
covergroups sampled. Every load returned the correct value.

The real impact was not on the design — it was on **trust in the pass criterion**.
This is what exposed O-001 below: SVA failures never reach the UVM report server,
so the summary line everybody reads was actively misleading. Without noticing the
assertion output scrolling past above it, the run would have been recorded as
clean and the environment's headline number would have been wrong from the first
entry onwards.

### Root cause

The snoop acknowledgement is a register, cleared only once `sn_active` has
already fallen:

```systemverilog
if (!sn_active)      sn_ack_q <= 1'b0;
else if (sn_take)    sn_ack_q <= 1'b1;
```

`sn_active` is `snoop_valid && snoop_sel[CORE_ID]`, both driven combinationally
from the interconnect's state register. When the interconnect leaves `B_SNOOP`,
`snoop_valid` falls immediately but `sn_ack_q` does not clear until the following
edge — leaving exactly one cycle with `ack` high and `sel` low.

### How the fix was reached

The failure *pattern* was the first useful clue. It fired on every single bus
transaction, at perfectly regular intervals, alternating cleanly between cache 0
and cache 1. Races and corner cases do not look like that. A defect that
reproduces on 100% of transactions is structural — something about the steady
state is wrong, not something about a rare interleaving. That immediately ruled
out arbitration, timing and stimulus, and pointed at the signal definition.

From there the question is which side of the boundary is registered and which is
combinational. `sn_ack_q` is a flop; `snoop_valid` is combinational off `bst_q`.
A one-cycle skew between a registered response and a combinational qualifier is
the textbook shape of this bug.

Then the judgement call: **is this actually harmful?** Worth establishing before
deciding how to fix it, because the answer changes what a reasonable fix is. The
interconnect samples `snoop_ack` only while in `B_SNOOP`, so the risk is a stale
ack being misread as a fresh one at the *start* of the next snoop. The shortest
route back into `B_SNOOP` is a `CleanUnique`:
`B_SNOOP → B_DONE → B_IDLE → B_SNOOP`. That is two edges, and `sn_ack_q` clears
on the first of them. So it cannot happen — benign, and demonstrably so rather
than assumed.

Benign meant relaxing the assertion was genuinely on the table:

```systemverilog
snoop_ack |-> (snoop_valid && snoop_sel) || $past(snoop_valid && snoop_sel)
```

Rejected, for two reasons. First, it trades a real guarantee for a cosmetic pass
— the property would no longer state a clean protocol rule, it would state "the
rule, plus whatever the RTL happens to do." Second, and more corrosive, the
one-cycle tail would become invisible: a future reader sees an assertion that
looks deliberately weakened and has no way to know whether that was principled or
just someone silencing a failure. Weakening checkers to match imprecise RTL is
how a checker set rots.

Gating the output makes the property true by construction, so the assertion can
keep saying exactly what it means. Before committing, traced the new
combinational path for a loop:
`bst_q → snoop_valid → sn_active → snoop_ack → sn_all_ack → next bst_q`. It
terminates at a register — ordinary FSM next-state logic.

### Fix

```systemverilog
assign bus.snoop_ack[CORE_ID] = sn_ack_q && sn_active;
```

### Confirmation

Re-ran `smoke_test` on the same seed. Zero assertion output, and the scoreboard
and coverage numbers were **byte-identical** to the failing run — same 7 loads,
3 stores, 10 transitions, 65.34 % coverage. That equivalence is the useful part:
it shows the gate removed the protocol violation without perturbing behaviour,
which is what distinguishes a fix from a change that merely stops the complaint.

### Takeaway

**The scoreboard could never have found this.** Every load returned the right
value; there was nothing for a data checker to object to. Protocol assertions
cover a class of defect that transaction-level checking is structurally blind to,
and this is the concrete example of why both exist.

---

## D-004 — `cg_alloc` sampled on tag change, so allocation into a free way was invisible

**Found by:** `mesi_walk_test`, first run, VCS X-2025.06-SP1
**Severity:** coverage model reports a hole that is not there, and hides one that is
**File:** [verif/env/cache_coverage.sv](../verif/env/cache_coverage.sv)

### Symptom

The test passed — 0 UVM errors, 0 assertion failures, and the walk printed all
ten transitions. But the coverage table read:

```
cg_core    56.73 %
cg_bus     82.87 %
cg_mesi    80.53 %
cg_alloc    0.00 %      <--
cg_axil   100.00 %
cg_share   87.50 %
```

`cg_alloc` at **exactly** 0.00 % while every other group moved. The same
covergroup had reported 72.57 % in `smoke_test`, so it was not broken outright.

### Impact on the work

`cg_alloc` exists to prove two distinct paths both ran: allocation into a **free**
way, and a real PLRU-driven eviction of a **valid** one. It has an explicit
`bins free = {MESI_I}` for the first.

A test that fills three lines into an empty cache does nothing *but* allocate into
free ways. Reporting 0.00 % is therefore not a coverage gap — it is the coverage
model failing to observe an event that certainly happened, six or more times.

That direction of error is the dangerous one. A covergroup that under-reports
makes you chase stimulus you already have, and worse, it means the `free` bin was
only ever credited by accident in earlier runs. Coverage you cannot trust is
worse than no coverage, because it is quoted as evidence.

### Root cause

The sampling gate used a tag change as a proxy for "an allocation happened":

```systemverilog
if (tag_changed)
  cg_alloc.sample(it.old_state, it.way_idx, ...);
```

The proxy fails when the incoming tag already equals the stale tag sitting in the
invalid way. Three facts line up to make that certain here:

- `l1_cache` resets the tag array to zero — `tag_q[s][w] <= '0`
- `probe_monitor` initialises its shadow `prev_tag` to zero to match
- `mesi_walk_vseq` walks lines at `0x00`, `0x10`, `0x20`, which with a 16-byte
  line and 16 sets differ only in **index**. All three have tag `0`

So every fill was `tag 0x0 -> 0x0`, `tag_changed` was false, and the covergroup
was never sampled. `cg_mesi` still saw the `I->E` and `I->S` transitions, which is
why only one group flatlined.

`smoke_test` hid this because random addresses over 4 KB almost always produce a
differing stale tag. The bug was always there; it took a directed test using low
addresses to expose it.

### How the fix was reached

The 0.00 % was read as a *contradiction*, not a gap. `cg_mesi` had recorded `I->E`
transitions in the same run, and an `I->E` transition on a way **is** an
allocation. Two views of the same event disagreeing localises the fault to the
sampling gate, without needing a waveform.

The check that made it certain: the sampled value is `it.old_state`, and the
group has a bin for `MESI_I`. If the gate requires the tag to change, then the
`free` bin is only reachable when an invalid way happens to hold a *different*
stale tag — which is a property of the address stream, not of the design. The
gate and the bins were describing different events.

Considered and rejected: **widening the address range in `mesi_walk_vseq`** so the
tags differ. That would have made the number go up while leaving the model wrong,
and the walk deliberately uses adjacent lines so it stays inside one set group
and is easy to read in a waveform. Fixing stimulus to satisfy a broken checker is
the wrong direction.

### Fix

State the actual predicate — a way is being *installed with a line* — instead of a
proxy for it:

```systemverilog
if (it.new_state != MESI_I && (tag_changed || it.old_state == MESI_I))
  cg_alloc.sample(it.old_state, it.way_idx, index_t'(it.set_idx), it.core_id);
```

Both allocation paths are now covered by construction: `old_state == MESI_I` is
the fill into a free way, `tag_changed` with a valid old state is the clean
eviction. Dirty victims still cannot reach the `illegal_bins dirty` bin, because
the RTL takes `M -> I` through a writeback first and the fill then starts from
`I` — which is exactly the property that bin is there to police.

### Confirmation

Re-ran `mesi_walk_test`:

| | Before | After |
|---|---|---|
| `cg_alloc` | 0.00 % | **44.79 %** |
| `cg_core` | 56.73 % | 56.73 % |
| `cg_bus` | 82.87 % | 82.87 % |
| `cg_mesi` | 80.53 % | 80.53 % |
| `cg_axil` | 100.00 % | 100.00 % |
| `cg_share` | 87.50 % | 87.50 % |
| OVERALL | 67.94 % | **75.40 %** |

Every other covergroup is identical to two decimal places, the scoreboard
counters are unchanged, and `$finish` lands at the same 3 635 000 ps. Only the
group with the broken gate moved. A coverage change that moves *one* number is a
fix; one that moves several would mean the sampling change had perturbed the run,
and would need explaining before it could be trusted.

The residual 55 % is now a real gap rather than an artefact: `cp_set` has 16 bins
and the walk touches 3, and the `clean_shared` / `clean_exclusive` victim bins
require an actual eviction, which only `eviction_test` produces.

`pingpong_test` then confirmed the fix a second time, independently. It hammers a
**single address**, so the tag never changes for the entire run — under the old
gate it would also have reported 0.00 %. It reports 42.71 %, credited entirely
through the `old_state == MESI_I` path as the line is invalidated and refetched.
That is the exact case the original gate was blind to, reached by a completely
different test.

### Takeaway

**A covergroup at 0.00 % is a bug report, not a coverage gap.** Nothing in the
tool flow flags a covergroup that never samples; it reports 0 % identically to
one that samples constantly and misses every bin. The two mean completely
different things and only the engineer can tell them apart.

More generally: the checker was written against a *proxy* for the event
(`tag_changed`) rather than the event itself (a line being installed). Proxies
work until stimulus finds the case where they diverge. This is the same class of
mistake as D-003 — the difference is that D-003 was caught by an assertion,
whereas this one had to be caught by reading a number that looked wrong.

---

## D-005 — The message-passing litmus test was checking a property the design never promised

**Found by:** `producer_consumer_test`, first run, VCS X-2025.06-SP1
**Severity:** false failure — seven reported ordering violations, none real
**File:** [verif/env/seq_lib/cache_vseq_lib.sv](../verif/env/seq_lib/cache_vseq_lib.sv)

### Symptom

Seven `UVM_ERROR`s, all from the sequence itself:

```
@1075000: flag=2652150544 payload=0xc0de0001 expected=0x5ef29b10
@2655000: flag=2         payload=0xc0de0003 expected=0xc0de0002
@3435000: flag=3         payload=0xc0de0004 expected=0xc0de0003
...
@6735000: flag=7         payload=0xc0de0008 expected=0xc0de0007
```

The scoreboard reported **zero** errors. No `SB_DATA`, no `SB_FINAL`, no illegal
bin, no assertion failure, 60 invariant sweeps clean.

### How the fix was reached

The direction of the mismatch settles it before any waveform is opened.

A consistency violation means the consumer sees the flag but a **stale** payload —
one written *before* the message it is reading. Every mismatch here is the
opposite: `flag=3` with `payload=0xc0de0004`. The payload is *newer* than the
flag by exactly one message, in all six of the well-formed cases.

Nothing in a coherence bug produces data from the future. The only way to read a
newer payload is for the producer to have genuinely written it, which means the
sequence's expectation was wrong, not the design's behaviour.

The independent confirmation is the golden memory. It knows the correct contents
of every address at every moment and was satisfied by **every single load in the
run, including the seven the sequence called violations**. Two checkers looking
at the same loads and disagreeing localises the fault to the one making the
stronger claim.

### Root cause — two separate defects

**1. The expectation assumed a quiesced producer.** The consumer read the flag,
latched `seen_flag`, then read the payload and required *exactly*
`payload_of(seen_flag)`. But producer and consumer run in a `fork`, so between
those two loads the producer can complete another message. A payload one ahead of
the flag is correct behaviour that the check called a failure.

The property the design actually offers is weaker and is the real litmus
condition: **the payload may be newer than the flag, never older.**

**2. The flag was never initialised.** The first error shows
`flag=2652150544` — not a message index at all. That is
`mem_model::backing_value()`, the deterministic hash returned for unwritten
addresses. The consumer's `while (seen_flag < k)` guard was satisfied instantly
by a garbage value on the very first poll, before the producer had written
anything.

This is a direct collision between two deliberate design decisions. Returning a
hash for unwritten memory removes the "X on first read" blind spot and is
documented as such; the litmus sequence silently assumed memory starts at zero.
Both were reasonable in isolation.

### Fix

Seed the flag before forking, and check the weaker, correct property:

```systemverilog
// Unwritten memory returns a hash of its address, not zero, so the flag has
// to be seeded below the first message index before the consumer polls it.
s = core_single_seq::type_id::create("flag_init");
... op == CORE_STORE; addr == flag_addr; wdata == '0; ...
```

```systemverilog
// The producer runs concurrently, so by the time this load completes the
// payload may legitimately be newer than the flag we observed. The
// ordering property is that it can never be *older*.
if (s.observed_rdata[31:16] !== 16'hc0de ||
    s.observed_rdata[15:0]   <  seen_flag[15:0])
  `uvm_error(...)
```

### Confirmation

Re-ran `producer_consumer_test`: **0 UVM errors**, and no
`[producer_consumer_vseq]` entries in the report summary at all.

```
[SB]  loads=25 stores=17 touched_words=2
      ReadShared=14 ReadUnique=2 CleanUnique=12 WriteBack=0
      state transitions=54  invariant sweeps=54
UVM_ERROR : 0
```

`stores` went 16 -> 17, which is the single added `flag_init` write and a useful
check that the seeding actually happened. `touched_words=2` confirms the test
still touches only the payload and flag addresses.

### Takeaway

**A checker that is too strong is a checker that is wrong.** This one asserted a
property the design never claimed — that the producer stops between messages —
and would have failed on correct RTL forever.

Worth noting where the time did *not* go: no waveform, no bisect, no RTL reading.
The mismatch direction plus the scoreboard's silence identified the faulty
component in two observations. When two checkers disagree about the same
transaction, the question is which one is overclaiming, and the answer is usually
the more specific one.

---

# Observations

Not code defects, but things that cost time or would have misled us.

## O-001 — `UVM_ERROR : 0` does not mean the test passed

The first successful `smoke_test` reported:

```
UVM_ERROR :    0
UVM_FATAL :    0
```

while D-003's assertions were failing on every single bus transaction.

**SVA failures are reported by the simulator's assertion engine, not through
`uvm_report_server`**, so they never appear in the UVM summary. Any pass/fail
automation that greps only `UVM_ERROR` will report a false pass.

Already mitigated in `sim/Makefile`'s `bugs` target, which counts illegal-bin and
assertion hits separately. Any future regression scoring must do the same.

## O-002 — Questa Starter compiles class-based SV but will not simulate it

```
** Error: Failure to checkout svverification license feature.
** Error: (vsim-1) Unable to checkout verification license - required for
   testbench features (randomize, randcase, randsequence, covergroup).
```

`vlog` and `vopt` work fully; only `vsim` is blocked. That distinction is what
made the local tool still useful — the entire design can be compile- and
elaboration-checked locally, which is how D-001 was found.

The two standalone probes (`sim/tool_check.sv`, `sim/tool_check_uvm.sv`)
identified this boundary in about five minutes, versus discovering it through
cascading errors in a 3700-line bundle.

## O-003 — Manual file copying has no staleness detection

`vlog -f braytcache.f` failed with `ENOENT` because the run machine held a copy
predating a filename change. Copying *over* an existing directory is worse than
replacing it: both the old and new filelist survive, the build succeeds, and
there is no way to tell which one was used.

Delete the destination directory before each copy.

## O-004 — Git Bash does not ship GNU Make

`make --version` fails on a stock Git for Windows install. Bash, grep, sed, awk
and find are all present; make is not. The `vlib`/`vlog`/`vsim` commands are the
portable interface — everything else is a convenience wrapper.

## O-005 — Illegal bins abort the run and exit non-zero; assertions do not

The first bug-injection run, `+define+BUG_1` under `eviction_test`:

```
Error-[FCIBH] Illegal bin hit
  At time 1455000 ps, Illegal bin m_to_e of cross x_trans in covergroup
  cache_uvm_pkg::cache_coverage::cg_mesi got hit with sample values
  cp_old=MESI_M cp_new=MESI_E cp_tagc=0x0
Exit code expected: 0, received: 1
```

This is the direct counterpoint to [O-001](#o-001--uvm_error--0-does-not-mean-the-test-passed).
The three reporting mechanisms in this environment fail in three different ways,
and only one of them is safely scriptable:

| Mechanism | Reaches UVM summary | Aborts run | Exit code |
|---|---|---|---|
| `uvm_error` from the scoreboard | yes | no | 0 |
| SVA failure | **no** | no | 0 |
| Illegal bin hit | **no** | **yes** | **1** |

So a CI script that greps `UVM_ERROR` misses assertion failures entirely, and a
script that checks only the exit code misses scoreboard errors. `make bugs` was
already written to count assertion and illegal-bin hits separately, which turns
out to have been the right call for a reason that only became visible here.

The secondary consequence is that an illegal bin hit **truncates the run**: no
scoreboard summary, no coverage table, no UVM report summary. `BUG_1` also
violates the SWMR invariant, and the scoreboard would have caught it moments
later, but that never happens because the covergroup aborts first. The redundancy
between the two checkers is real and untested. Demonstrating it would mean
temporarily removing the illegal bins, which is not worth doing for a bug that is
already caught precisely and early.

Worth noting how good the diagnostic is: the message states the injected defect
verbatim — a line moved **M** to **E** with no tag change — with no inference
step between failure and cause, at 1.46 us into a run that takes 18.7 us clean.

### Confirmed by `BUG_3`

The `BUG_3` run is the other half of the table. It produced 11 `UVM_ERROR`s,
ran to completion, printed a full coverage table, and **exited 0**. A regression
script keyed on exit code alone would have called that run a pass while the
scoreboard was reporting eleven data corruptions.

The two runs together demonstrate that neither signal is sufficient on its own:
`BUG_1` exits 1 with nothing in the UVM summary, `BUG_3` exits 0 with eleven
errors in it. Any pass/fail decision has to read both.

## O-006 — 100 % functional coverage would not have caught `BUG_3`

The `+define+BUG_3` run reported coverage **byte-identical** to the clean run:

```
cg_core 86.61 | cg_bus 97.22 | cg_mesi 98.95
cg_alloc 84.38 | cg_axil 100.00 | cg_share 100.00 | OVERALL 94.53 %
```

Same figures in all six groups, same `$finish` at 18 655 000 ps, same traffic
counters — `loads=28 stores=32`, `ReadShared=17 ReadUnique=19 CleanUnique=2
WriteBack=14`, 68 transitions, 68 invariant sweeps. Eleven data corruptions were
present and the coverage model registered nothing at all.

The reason is structural rather than a gap to be closed. `BUG_3` changes only
which bytes a store writes; it changes no state, no transition, no bus operation
and no allocation decision. The covergroups sample control-path events, so a
defect confined to the data path is outside what they are able to observe. Adding
bins would not help — there is no event to bin.

**This is the concrete refutation of "coverage closed, therefore done".** Coverage
measures whether stimulus reached a situation; it says nothing about whether the
result was right. The golden memory is what answers the second question, and the
two mechanisms are not substitutes for one another at any coverage percentage.

A secondary point from the same run: of the six end-of-test `SB_FINAL`
mismatches, four were at addresses **no load ever read back**. Live checking
alone would have missed them, and the end-of-test reconciliation is the only
reason they were reported.

## O-007 — Detection latency tracks how often the mutated path executes

Three injected bugs, all under `eviction_test +num_txns=30`, all detected:

| Bug | Mutated path | Times that path runs (clean) | Detected at |
|---|---|---|---|
| `BUG_1` | snoop response to `ReadShared` | 17 | 1.46 us |
| `BUG_5` | fill state after `ReadShared` | 17 | 1.80 us |
| `BUG_4` | dirty victim eviction | 14 | 3.67 us |
| `BUG_2` | snoop response to `CleanUnique` | 2 | 7.68 us |
| `BUG_3` | store hit byte merge | 32 stores | 7.64 us, first observation |

Across the four bugs that abort on an illegal bin, **detection time is monotonic
in path frequency**: 17, 17, 14, 2 executions map to 1.46, 1.80, 3.67, 7.68 us.
Same test, same checker family, same abort mechanism — execution frequency is
the only variable that differs, and it orders the results without exception.

`BUG_3` sits outside that ordering because it is caught by a different mechanism
entirely. Its mutated path runs most often of all (32 stores), yet it is among
the slowest to detect, because the golden memory cannot complain until the
corrupted value is *read back*. A covergroup samples the event; a data checker
has to wait for the consequence. That gap is the argument for having both.

**The corollary is a hazard, and it is measurable rather than hypothetical.** The
clean `smoke_test` run reported `ReadShared=7 ReadUnique=3 CleanUnique=0
WriteBack=0`. Those two zeroes mean `BUG_2` and `BUG_4` are **provably**
undetectable under `smoke_test` — not because the checkers are weak, but because
the mutated lines never execute at all.

So a bug-injection matrix has to be read as bug × test, never bug alone. A green
row proves the checkers work *for that stimulus*; a clean run for a bug the
stimulus cannot reach proves nothing and must not be recorded as a pass. The
traffic counters in the `[SB]` summary — `ReadShared`, `ReadUnique`,
`CleanUnique`, `WriteBack` — are what tell you which of the two you are looking
at, which is a good reason for the scoreboard to print them even on a clean run.

## O-008 — An illegal bin abort hides whichever detector would have fired second

`BUG_4` had three candidate detectors: `cg_mesi`'s `dirty_dropped`, `cg_alloc`'s
`illegal_bins dirty`, and the end-of-test memory reconciliation. `cg_mesi` fired.
The other two did not — and the reason is nothing to do with their quality:

```systemverilog
function void write_probe(probe_item it);
  ...
  cg_mesi.sample(...);                     // sampled first, aborts here
  if (it.new_state != MESI_I && (...))
    cg_alloc.sample(...);                  // never reached
```

Both covergroups are sampled from the same analysis write, on the same probe
item, describing the same event. `cg_mesi` won on **statement order**, not on
merit, and the simulation terminated before `cg_alloc` was evaluated or the
reconciliation phase ran.

This matters for how results are reported. It would be easy to write "`BUG_4` is
caught by three independent mechanisms" — the design intent — when what was
actually demonstrated is that **one fired and two are reachable but unproven**.
Confirming the others means removing the winning bin and re-running, which is a
legitimate experiment but was not done here.

The general lesson: a fail-fast checker gives excellent detection latency and
poor information about redundancy. If defence in depth is a claim you want to
make, the abort has to be defeated deliberately to measure it.

## O-009 — Coverage percentages are not comparable across configurations

`eviction_test` on the two geometries:

| | 2-way / 16-set | 4-way / 8-set |
|---|---|---|
| `cg_alloc` | 84.38 % | **72.92 %** |
| `cg_mesi` | 98.95 % | 94.74 % |
| OVERALL | 94.53 % | **92.06 %** |

Read naively, the 4-way build looks *less* well verified. It is not. The bins
changed underneath the number:

- `cp_way` went from 2 bins to 4
- `x_victim_way` went from 6 bins to 12
- `cp_set` went from 16 bins to 8

So the denominator grew for the way-related coverpoints. At the same time the
*numerator* shrank, because a 4-way set absorbs a working set that thrashed a
2-way one: `WriteBack` fell from 14 to 3 and total state transitions from 68 to
55. **More bins to fill, fewer events to fill them with.** A lower percentage
here is the arithmetic working correctly, not a regression.

The trap is real because both numbers are printed by the same table in the same
format and invite direct comparison. Anything that changes bin construction —
geometry, core count, a new coverpoint — resets the baseline, and percentages
either side of that change describe different questions.

Two consequences worth carrying:

1. A coverage figure is only meaningful alongside the configuration that
   produced it. The `[CFG]` line the test prints at time 0 exists for exactly
   this reason and should be quoted with any number taken from a run.
2. Regression thresholds cannot be a single global percentage. They have to be
   per-configuration, or expressed as *bins hit* rather than *percentage of bins*.

## O-010 — A passing run disproved a documentation claim, via the traffic counters

`store_streak_test` passed with zero errors. Its scoreboard line read:

```
loads=0 stores=90 touched_words=5
ReadShared=0 ReadUnique=5 CleanUnique=0 WriteBack=0
```

The README described this test as targeting **both** silent paths in MESI: the
`E->M` upgrade and the run of **M** hits. `ReadShared=0` disproves half of that.

Entering **E** requires a `ReadShared` that finds no other holder, and
`ReadShared` is only issued on a **load** miss. This sequence issues no loads, so
every acquisition is a `ReadUnique` straight to **M** and no line is ever **E**.
`CleanUnique=0` follows for the same reason — no line reaches **S** either. The
`E->M` path is exercised by `mesi_walk_test`, which loads before storing.

The interesting part is the detection route. No check fired. No coverage bin went
unexpectedly cold. The test did exactly what it was written to do, and the design
was correct throughout. The error was in the *description*, and the only thing
that exposed it was reading the traffic counters on a green run and noticing they
did not match the story.

**This is the argument for the scoreboard printing `ReadShared` / `ReadUnique` /
`CleanUnique` / `WriteBack` even when everything passes.** Those four numbers are
a cheap, always-on summary of *which protocol paths the stimulus actually
reached*, and they are the only way to notice that a test is not doing what its
name and comment claim. A pass tells you nothing about coverage of intent.

The generalisable habit: on a clean run, check that the traffic profile matches
what the test was written to produce, before moving on. `read_mostly_test` was
checked the same way on the next run — `ReadUnique=0 CleanUnique=0 WriteBack=0`
was a prediction recorded in advance, and it held.

---

## O-011 — A `default` bin is silently excluded from every cross it appears in

Found by reading `cg_core` during a review pass, not by any run. `cp_be` is:

```systemverilog
cp_be : coverpoint be {
  bins full     = {(1 << STRB_W) - 1};
  bins single[] = {1, 2, 4, 8};
  bins partial  = default;
}

x_op_be : cross cp_op, cp_be { ... }
```

IEEE 1800 §19.5 states that a `default` bin does not participate in cross
coverage. So `x_op_be` is not the 2 × 6 grid it reads as — the `partial` bin is
absent, and every genuinely partial byte enable (`4'b0011`, `4'b0111`, …) is
sampled into a bin that the cross cannot see. The cross covers full-word and
single-byte accesses only.

**Why this matters more than the missing bins.** The covergroup *reports* 99.11 %
and nothing anywhere says a category of stimulus is unmeasured. A coverage model
can be wrong in a direction that inflates confidence, and the number gives no
hint. This is the same lesson as [O-006](#o-006--100--functional-coverage-would-not-have-caught-bug_3)
arriving from the opposite side: there, full coverage did not imply correctness;
here, a high percentage does not even imply the model measures what it appears to.

**Not fixed.** Replacing `default` with an explicit `bins partial[] = {...}` of
the ten remaining non-trivial masks would change every coverage figure in the
README, all of which were produced by real runs. The correct order is to fix it
and re-run the suite, not to fix it and leave stale numbers in place. Recorded
here so the number is not defended as if it were sound.

---

## O-012 — The Playground bundler is a second, unchecked copy of the filelist

`sim/braytcache.f` lists the compile order for Questa. `sim/bundle_playground.py`
hard-codes the same order again in its `DESIGN` and `TESTBENCH` lists. Nothing
compares them.

A file added to `braytcache.f` alone compiles clean under Questa and is simply
absent from the Playground bundle — which fails in a browser, against flattened
line numbers, with a message pointing at whatever first referenced the missing
type. The two tools that were chosen precisely because they catch different
classes of bug ([D-001](#d-001--bind-at-compilation-unit-scope-silently-drops-every-cache-assertion),
[D-002](#d-002--1-before-run_test-fatals-under-uvm-12)) are being fed by two
independently maintained lists.

It has not bitten yet because the file set stopped changing before the bundler
was written. The fix is for `bundle_playground.py` to parse `braytcache.f` and
derive the two panes from it, splitting on `verif/sva/` — which is the actual
rule, since the Design pane is "everything with no UVM dependency". Recorded
rather than done because it is a build change, and build changes made after the
last green run are how a reproducible result stops being reproducible.

