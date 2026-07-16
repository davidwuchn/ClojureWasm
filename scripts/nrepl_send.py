#!/usr/bin/env python3
"""Send eval(s) to a running cljw/clj nREPL server — the quick debug tool.

Usage:
  python3 scripts/nrepl_send.py 7888 "(+ 1 2)"
  python3 scripts/nrepl_send.py 7888 -            # read code from stdin
  python3 scripts/nrepl_send.py 7888 --op describe
  python3 scripts/nrepl_send.py 7888 --op completions --prefix "Char" [--ns user]

Prints every response dict the server sends for the request (value / out /
err / status), so a REPL-only failure ("works in CLI, breaks over nREPL")
is reproducible outside the editor. NOTE: "eval" here is the nREPL wire
OP name — evaluation happens in the TARGET nREPL server the caller
already controls; this script never eval()s anything locally. Uses the shared bencode client
(scripts/nrepl_bencode.py); no dependencies beyond python3.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from nrepl_bencode import NreplClient


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port", type=int)
    ap.add_argument("code", nargs="?", help="code to eval; '-' reads stdin")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--op", default="eval", help="nREPL op (default eval)")
    ap.add_argument("--prefix", help="completions prefix")
    ap.add_argument("--ns", help="ns for the op")
    ap.add_argument("--sym", help="lookup/eldoc symbol")
    args = ap.parse_args()

    cl = NreplClient(args.host, args.port)
    try:
        cl.clone()
        msg = {"op": args.op}
        if args.op == "eval":
            code = args.code or "-"
            msg["code"] = sys.stdin.read() if code == "-" else code
        elif args.code:
            msg["code"] = args.code
        if args.prefix is not None:
            msg["prefix"] = args.prefix
        if args.ns is not None:
            msg["ns"] = args.ns
        if args.sym is not None:
            msg["sym"] = args.sym
        for r in cl.request(msg):
            print(r)
    finally:
        cl.close()


if __name__ == "__main__":
    main()
