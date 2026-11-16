#!/usr/bin/env python3
"""ACP smoke test for a pi-acp binary.

Speaks the Agent Client Protocol (JSON-RPC 2.0, newline-delimited over stdio)
to the given adapter: `initialize` -> `session/new` -> optionally one prompt.

Exit code 0 when every check passes, 1 otherwise.

  python3 scripts/acp-smoke.py --command out/pi-acp-darwin-arm64 \
      --pi out/pi-darwin-arm64 --cwd /tmp            # handshake only
  python3 scripts/acp-smoke.py --command pi-acp --prompt   # also spend tokens
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import subprocess
import sys
import tempfile
import threading
import time


class Client:
    def __init__(self, command, env):
        self.proc = subprocess.Popen(
            command,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            bufsize=1,
            env=env,
        )
        self.messages = queue.Queue()
        self.notifications = []  # session/update payloads, kept across requests
        self.stderr = []
        threading.Thread(target=self._read_stdout, daemon=True).start()
        threading.Thread(
            target=lambda: [self.stderr.append(l.rstrip()) for l in self.proc.stderr],
            daemon=True,
        ).start()
        self.next_id = 0

    def _read_stdout(self):
        for line in self.proc.stdout:
            line = line.strip()
            if not line:
                continue
            try:
                self.messages.put(json.loads(line))
            except json.JSONDecodeError:
                self.messages.put({"type": "garbage", "raw": line})

    def request(self, method, params, timeout=120):
        self.next_id += 1
        req_id = self.next_id
        self._send({"jsonrpc": "2.0", "id": req_id, "method": method, "params": params})
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                msg = self.messages.get(timeout=max(0.1, deadline - time.time()))
            except queue.Empty:
                break
            self._absorb(msg, req_id)
            if msg.get("id") == req_id:
                return msg
        raise TimeoutError(f"{method}: no response in {timeout}s")

    def _absorb(self, msg, req_id):
        """Keep what request() must not drop: streamed notifications."""
        if msg.get("method") == "session/update":
            self.notifications.append(msg["params"]["update"])

    def drain(self, seconds=0.5):
        """Collect notifications still in flight for up to SECONDS."""
        deadline = time.time() + seconds
        while time.time() < deadline:
            try:
                msg = self.messages.get(timeout=max(0.05, deadline - time.time()))
            except queue.Empty:
                break
            self._absorb(msg, None)
        return self.notifications

    def _send(self, obj):
        self.proc.stdin.write(json.dumps(obj) + "\n")
        self.proc.stdin.flush()

    def close(self):
        try:
            self.proc.stdin.close()
            self.proc.wait(timeout=10)
        except Exception:
            self.proc.kill()

    def stderr_text(self):
        return "\n".join(self.stderr[-20:])


def fail(step, detail, client=None):
    print(f"FAIL {step}: {detail}", file=sys.stderr)
    if client and client.stderr:
        print("--- adapter stderr ---\n" + client.stderr_text(), file=sys.stderr)
    return 1


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--command", required=True, help="pi-acp executable")
    ap.add_argument("--pi", help="pi executable to pin via PI_ACP_PI_COMMAND")
    ap.add_argument("--cwd", help="session cwd (default: a temp dir)")
    ap.add_argument("--prompt", action="store_true",
                    help="send one prompt and expect assistant text (costs tokens)")
    ap.add_argument("--timeout", type=int, default=180,
                    help="per-request timeout in seconds (default 180)")
    args = ap.parse_args()

    cwd = args.cwd or tempfile.mkdtemp(prefix="pi-acp-smoke-")
    env = dict(os.environ)
    if args.pi:
        env["PI_ACP_PI_COMMAND"] = os.path.abspath(args.pi)

    client = Client([args.command], env)
    try:
        res = client.request("initialize", {
            "protocolVersion": 1,
            "clientCapabilities": {
                "fs": {"readTextFile": True, "writeTextFile": True},
                "terminal": True,
            },
        }, timeout=args.timeout)
        if "error" in res:
            return fail("initialize", res["error"], client)
        result = res["result"]
        caps = result.get("agentCapabilities", {})
        prompt_caps = caps.get("promptCapabilities", {})
        if result.get("protocolVersion") != 1:
            return fail("initialize", f"protocolVersion={result.get('protocolVersion')}", client)
        print(f"ok   initialize: {result.get('agentInfo', {}).get('name')} "
              f"(loadSession={caps.get('loadSession')}, "
              f"embeddedContext={prompt_caps.get('embeddedContext')})")
        client.drain(0.3)

        res = client.request("session/new", {"cwd": cwd, "mcpServers": []},
                             timeout=args.timeout)
        if "error" in res:
            return fail("session/new", res["error"], client)
        session_id = res["result"].get("sessionId")
        if not session_id:
            return fail("session/new", f"no sessionId in {res['result']}", client)
        options = res["result"].get("configOptions", [])
        summary = ", ".join(f"{o.get('id')}={o.get('currentValue')}" for o in options)
        print(f"ok   session/new: {session_id} (config: {summary or 'none'})")

        if args.prompt:
            seen = len(client.notifications)  # ignore the startup info block
            res = client.request("session/prompt", {
                "sessionId": session_id,
                "prompt": [{"type": "text", "text": "Reply with exactly: OK"}],
            }, timeout=args.timeout)
            if "error" in res:
                return fail("session/prompt", res["error"], client)
            stop = res["result"].get("stopReason")
            text = "".join(
                u.get("content", {}).get("text", "")
                for u in client.drain(1.0)[seen:]
                if u.get("sessionUpdate") == "agent_message_chunk"
            )
            if "OK" not in text:
                return fail("session/prompt", f"no 'OK' in reply ({text[:200]!r})", client)
            print(f"ok   session/prompt: stopReason={stop}, reply contains OK")

        print("PASS")
        return 0
    except TimeoutError as exc:
        return fail("timeout", str(exc), client)
    finally:
        client.close()


if __name__ == "__main__":
    sys.exit(main())