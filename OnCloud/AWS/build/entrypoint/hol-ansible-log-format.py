#!/usr/bin/env python3
"""HoL parallel Ansible log helper: prefix service tags; compact skip task lines."""

from __future__ import annotations

import json
import re
import sys
from typing import Any, Dict, List, Optional

SKIP_COMPACT_NOISE_KEYS = frozenset({
    "invocation", "cmd", "stdout", "stderr", "stdout_lines", "stderr_lines",
    "module_stdout", "module_stderr", "start", "end", "delta", "rc", "warnings",
    "item", "results", "ansible_facts",
})


def skip_reason_from_obj(obj: Any) -> Optional[str]:
    if not isinstance(obj, dict):
        return None
    fc = obj.get("false_condition")
    if fc is not None and fc is not False:
        return f"false_condition: {fc}"
    sr = obj.get("skip_reason")
    if sr:
        return f"skip_reason: {sr}"
    msg = obj.get("msg")
    if isinstance(msg, str) and msg:
        return msg if len(msg) <= 160 else msg[:157] + "..."
    return None


def compact_skip_obj(obj: Any) -> Any:
    if not isinstance(obj, dict):
        return obj
    reason = skip_reason_from_obj(obj)
    compact: Dict[str, Any] = {}
    for key in ("false_condition", "skip_reason", "msg", "changed", "ansible_loop_var"):
        if key in obj:
            compact[key] = obj[key]
    if compact:
        return compact
    for key, val in obj.items():
        if key in SKIP_COMPACT_NOISE_KEYS or key.startswith("_ansible"):
            continue
        if isinstance(val, (dict, list)):
            continue
        if isinstance(val, str) and len(val) > 120:
            val = val[:117] + "..."
        compact[key] = val
    if reason and not compact:
        return {"reason": reason}
    return compact


def format_skip_line(text: str) -> str:
    stripped = text.strip()
    if " — " in stripped and " => {" not in stripped:
        return stripped
    marker = " => "
    if marker not in stripped:
        return stripped
    idx = stripped.rfind(marker)
    head = stripped[:idx].rstrip()
    payload = stripped[idx + len(marker):].strip()
    if not payload or payload[0] not in "{[":
        return stripped
    try:
        obj = json.loads(payload)
    except json.JSONDecodeError:
        return stripped[:400] + ("..." if len(stripped) > 400 else "")
    reason = skip_reason_from_obj(obj)
    if reason:
        return f"{head} — {reason}"
    compact = compact_skip_obj(obj)
    return f"{head} => {json.dumps(compact, sort_keys=True)}"


def is_task_skip_line(text: str) -> bool:
    return bool(re.match(r"^skipping:\s+\[", text))


def print_tagged_ansible_log_line(tag: str, line: str) -> None:
    """Prefix parallel service log lines; compact skip tasks only."""
    prefix = f"[{tag}] "
    if is_task_skip_line(line):
        print(prefix + format_skip_line(line))
        return
    print(prefix + line)


def main(argv: Optional[List[str]] = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if not args:
        sys.stderr.write("usage: hol-ansible-log-format.py format-tagged-line TAG LINE\n")
        return 2

    cmd = args[0]
    if cmd == "format-tagged-line":
        if len(args) < 3:
            sys.stderr.write("usage: format-tagged-line TAG LINE\n")
            return 2
        print_tagged_ansible_log_line(args[1], args[2])
        return 0

    sys.stderr.write(f"unknown command: {cmd}\n")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
