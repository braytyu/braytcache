#!/usr/bin/env python3
"""Flatten the source tree into the two panes EDA Playground expects.

Playground cannot resolve +incdir or relative `include paths, so every
`include is expanded inline here. Include guards keep the expansion safe.

    python3 bundle_playground.py
    -> playground/design.sv      (paste into the Design pane)
    -> playground/testbench.sv   (paste into the Testbench pane)
"""

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "playground"

INCLUDE_RE = re.compile(r'^\s*`include\s+"([^"]+)"\s*$')
SKIP_INCLUDES = {"uvm_macros.svh"}

SEARCH_DIRS = [
    ROOT / "rtl",
    ROOT / "verif",
    ROOT / "verif" / "sva",
    ROOT / "verif" / "tb",
    ROOT / "verif" / "agents" / "core_agent",
    ROOT / "verif" / "agents" / "axil_agent",
    ROOT / "verif" / "agents" / "bus_agent",
    ROOT / "verif" / "agents" / "probe_agent",
    ROOT / "verif" / "env",
    ROOT / "verif" / "env" / "seq_lib",
    ROOT / "verif" / "tests",
]

DESIGN = [
    "rtl/cache_pkg.sv",
    "rtl/core_if.sv",
    "rtl/bus_if.sv",
    "rtl/axil_if.sv",
    "rtl/cache_probe_if.sv",
    "rtl/l1_cache.sv",
    "rtl/coherence_bus.sv",
    "rtl/cache_top.sv",
    "verif/sva/cache_sva.sv",
    "verif/sva/bus_sva.sv",
    "verif/sva/axil_sva.sv",
    "verif/sva/sva_bind.sv",
]

TESTBENCH = [
    "verif/cache_uvm_pkg.sv",
    "verif/tb/tb_top.sv",
]


def locate(name):
    for d in SEARCH_DIRS:
        p = d / name
        if p.is_file():
            return p
    return None


def expand(path, seen):
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = INCLUDE_RE.match(line)
        if not m:
            out.append(line)
            continue

        target = m.group(1)
        if target in SKIP_INCLUDES:
            out.append(line)
            continue

        found = locate(target)
        if found is None:
            print(f"warning: cannot resolve `include \"{target}\" in {path}", file=sys.stderr)
            out.append(line)
            continue

        if found in seen:
            continue
        seen.add(found)
        out.append(f"// ---- begin {found.relative_to(ROOT).as_posix()} ----")
        out.extend(expand(found, seen))
        out.append(f"// ---- end {found.relative_to(ROOT).as_posix()} ----")
    return out


def build(files, dest):
    seen = set()
    lines = []
    for rel in files:
        p = ROOT / rel
        if p in seen:
            continue
        seen.add(p)
        lines.append(f"// ================ {rel} ================")
        lines.extend(expand(p, seen))
        lines.append("")
    dest.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"{dest.relative_to(ROOT).as_posix()}: {len(lines)} lines")


def main():
    OUT.mkdir(exist_ok=True)
    build(DESIGN, OUT / "design.sv")
    build(TESTBENCH, OUT / "testbench.sv")


if __name__ == "__main__":
    main()
