#!/usr/bin/env python3
"""Completion oracle harness: run the SAME completion requests against
mainline Clojure (JVM nREPL + cider-nrepl) and/or cljw's nREPL, then
capture fixtures or show the parity diff.

The completion-parity campaign (user-directed, 2026-07-15) is e2e-first:
mainline's live responses are the oracle. This script is the capture +
audit half; the per-commit regression half is the fixture-driven e2e
(test/e2e/phase14_nrepl_completion.sh), which needs NO JVM.

Usage:
  python3 scripts/completion_oracle.py --capture   # mainline → fixture
  python3 scripts/completion_oracle.py --diff      # mainline vs cljw
  python3 scripts/completion_oracle.py --cljw      # cljw responses only

Requests spec: test/e2e/fixtures/completion/requests.json — a list of
scenario groups {group, setup: [code...], probes: [{prefix, ns}]}.
Fixture: test/e2e/fixtures/completion/expected.json — per "group|prefix"
the mainline candidate dicts normalized to the three keys CIDER reads
(candidate/type/ns; extra wire fields like package/file/priority are
dropped — cider-completion.el reads exactly those three), sorted by
candidate (the nREPL built-in `completions` op is by-name sorted).

Server lifecycle: both servers are spawned as children with explicit
kill in finally; the JVM gets -J-Xmx2g (orphan_prevention.md rule 3).
Wrap invocations in `timeout 600` from the shell (rule 1).
"""
import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nrepl_bencode import NreplClient

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURE_DIR = os.path.join(REPO, "test", "e2e", "fixtures", "completion")
REQUESTS = os.path.join(FIXTURE_DIR, "requests.json")
EXPECTED = os.path.join(FIXTURE_DIR, "expected.json")

MAINLINE_DEPS = ('{:deps {nrepl/nrepl {:mvn/version "1.3.1"} '
                 'cider/cider-nrepl {:mvn/version "0.62.1"}}}')


def wait_port_file(path, seconds):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if os.path.exists(path):
            with open(path) as f:
                txt = f.read().strip()
            if txt:
                return int(txt)
        time.sleep(0.2)
    raise SystemExit(f"no .nrepl-port within {seconds}s at {path}")


def start_mainline(workdir):
    """Headless JVM nREPL + cider-nrepl in `workdir`; returns (proc, port)."""
    proc = subprocess.Popen(
        ["clj", "-J-Xmx2g", "-Sdeps", MAINLINE_DEPS, "-M", "-m", "nrepl.cmdline",
         "--middleware", '["cider.nrepl/cider-middleware"]', "--port", "0"],
        cwd=workdir, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    port = wait_port_file(os.path.join(workdir, ".nrepl-port"), 120)
    return proc, port


def start_cljw(workdir, port):
    """cljw nrepl on an explicit port; returns (proc, port)."""
    binary = os.path.join(REPO, "zig-out", "bin", "cljw")
    proc = subprocess.Popen([binary, "nrepl", "--port", str(port)],
                            cwd=workdir, stdout=subprocess.DEVNULL,
                            stderr=subprocess.STDOUT)
    wait_port_file(os.path.join(workdir, ".nrepl-port"), 15)
    return proc, port


def normalize(cands):
    """Keep exactly the fields CIDER consumes; sort by candidate."""
    out = []
    for c in cands or []:
        d = {"candidate": c.get("candidate"), "type": c.get("type")}
        if "ns" in c:
            d["ns"] = c["ns"]
        out.append(d)
    return sorted(out, key=lambda d: d["candidate"] or "")


def run_probes(port, groups):
    """One fresh session per group (setup isolation); returns
    {"group|prefix": [normalized candidates]}."""
    result = {}
    for g in groups:
        cl = NreplClient("127.0.0.1", port)
        try:
            cl.clone()
            for code in g.get("setup", []):
                cl.request({"op": "eval", "code": code})
            for p in g["probes"]:
                res = cl.request({"op": "completions",
                                  "prefix": p["prefix"],
                                  "ns": p.get("ns", "user")})
                cands = next((r.get("completions") for r in res
                              if isinstance(r, dict) and "completions" in r), None)
                result[f'{g["group"]}|{p["prefix"]}'] = normalize(cands)
        finally:
            cl.close()
    return result


def stop(proc):
    proc.send_signal(signal.SIGTERM)
    try:
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()


def main():
    ap = argparse.ArgumentParser()
    mode = ap.add_mutually_exclusive_group(required=True)
    mode.add_argument("--capture", action="store_true",
                      help="run mainline, write the fixture")
    mode.add_argument("--diff", action="store_true",
                      help="run both servers, print the parity diff")
    mode.add_argument("--cljw", action="store_true",
                      help="run cljw only, print normalized responses")
    args = ap.parse_args()

    with open(REQUESTS) as f:
        groups = json.load(f)

    tmp = tempfile.mkdtemp(prefix="completion_oracle_")
    try:
        if args.capture or args.diff:
            m_proc, m_port = start_mainline(tmp)
            try:
                mainline = run_probes(m_port, groups)
            finally:
                stop(m_proc)
        if args.cljw or args.diff:
            cljw_dir = os.path.join(tmp, "cljw")
            os.makedirs(cljw_dir, exist_ok=True)
            c_proc, c_port = start_cljw(cljw_dir, 17000 + os.getpid() % 1000)
            try:
                cljw = run_probes(c_port, groups)
            finally:
                stop(c_proc)

        if args.capture:
            os.makedirs(FIXTURE_DIR, exist_ok=True)
            with open(EXPECTED, "w") as f:
                json.dump(mainline, f, indent=1, ensure_ascii=False, sort_keys=True)
                f.write("\n")
            print(f"captured {len(mainline)} probe responses -> {EXPECTED}")
        elif args.cljw:
            print(json.dumps(cljw, indent=1, ensure_ascii=False, sort_keys=True))
        else:
            diffs = 0
            for key in sorted(mainline):
                m, c = mainline[key], cljw.get(key)
                if m == c:
                    print(f"OK   {key} ({len(m)})")
                else:
                    diffs += 1
                    mset = {json.dumps(d, sort_keys=True) for d in m}
                    cset = {json.dumps(d, sort_keys=True) for d in (c or [])}
                    print(f"DIFF {key}: mainline {len(m)} vs cljw {len(c or [])}")
                    for line in sorted(mset - cset)[:15]:
                        print(f"  -mainline-only {line}")
                    for line in sorted(cset - mset)[:15]:
                        print(f"  +cljw-only     {line}")
            print(f"---\n{len(mainline) - diffs}/{len(mainline)} probes match")
            sys.exit(1 if diffs else 0)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    main()
