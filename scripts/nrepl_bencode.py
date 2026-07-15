#!/usr/bin/env python3
"""Minimal nREPL bencode client, shared by the completion oracle harness
(scripts/completion_oracle.py) and ad-hoc probing.

The encoder/decoder mirrors the inline implementations the nREPL e2e
scripts carry (test/e2e/phase14_nrepl.sh) — kept dependency-free so any
python3 can run it. Responses are plain dicts/lists/strs/ints; byte
strings are decoded as UTF-8 (replacement on error).
"""
import socket


def bencode(x):
    if isinstance(x, dict):
        return b"d" + b"".join(bencode(k) + bencode(v) for k, v in sorted(x.items())) + b"e"
    if isinstance(x, str):
        b = x.encode()
        return str(len(b)).encode() + b":" + b
    if isinstance(x, int):
        return b"i" + str(x).encode() + b"e"
    if isinstance(x, list):
        return b"l" + b"".join(bencode(v) for v in x) + b"e"
    raise TypeError(f"bencode: {type(x)}")


def bdecode(buf, i=0):
    """Decode one value at offset i. Returns (value, next_offset).
    Raises ValueError/IndexError on a truncated buffer."""
    c = buf[i:i + 1]
    if c == b"d":
        d = {}
        i += 1
        while buf[i:i + 1] != b"e":
            k, i = bdecode(buf, i)
            v, i = bdecode(buf, i)
            d[k] = v
        return d, i + 1
    if c == b"l":
        out = []
        i += 1
        while buf[i:i + 1] != b"e":
            v, i = bdecode(buf, i)
            out.append(v)
        return out, i + 1
    if c == b"i":
        j = buf.index(b"e", i)
        return int(buf[i + 1:j]), j + 1
    if c == b"":
        raise ValueError("empty")
    j = buf.index(b":", i)
    n = int(buf[i:j])
    end = j + 1 + n
    if end > len(buf):
        raise ValueError("truncated string")
    return buf[j + 1:end].decode("utf-8", "replace"), end


class NreplClient:
    """One nREPL connection; request() sends an op and collects response
    dicts until a `done` status arrives (or the socket times out)."""

    def __init__(self, host, port, timeout=20):
        self.sock = socket.create_connection((host, port), timeout=10)
        self.sock.settimeout(timeout)
        self.buf = b""
        self.counter = 0
        self.session = None

    def request(self, msg):
        self.counter += 1
        msg = dict(msg)
        msg.setdefault("id", f"req{self.counter}")
        if self.session and "session" not in msg:
            msg["session"] = self.session
        self.sock.sendall(bencode(msg))
        out = []
        while True:
            try:
                chunk = self.sock.recv(1 << 16)
            except socket.timeout:
                break
            if not chunk:
                break
            self.buf += chunk
            progressed = True
            while progressed:
                progressed = False
                try:
                    v, n = bdecode(self.buf)
                except (ValueError, IndexError):
                    continue
                out.append(v)
                self.buf = self.buf[n:]
                progressed = True
            if any(isinstance(r, dict) and "done" in r.get("status", []) for r in out):
                break
        return out

    def clone(self):
        res = self.request({"op": "clone"})
        self.session = next(r["new-session"] for r in res if isinstance(r, dict) and "new-session" in r)
        return self.session

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass
