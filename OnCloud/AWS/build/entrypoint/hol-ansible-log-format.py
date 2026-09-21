#!/usr/bin/env python3
"""Compact Ansible task result JSON for HoL Jenkins console (parallel service tailers)."""

from __future__ import annotations

import json
import re
import sys
from typing import Any, Dict, List, Optional, Union

SUMMARY_NOISE_KEYS = frozenset({
    "invocation", "stdout_lines", "stderr_lines", "module_stdout", "module_stderr",
    "start", "end", "delta", "warnings", "ansible_facts", "results",
})

SKIP_COMPACT_NOISE_KEYS = frozenset({
    "invocation", "cmd", "stdout", "stderr", "stdout_lines", "stderr_lines",
    "module_stdout", "module_stderr", "start", "end", "delta", "rc", "warnings",
    "item", "results", "ansible_facts",
})

SCALAR_KEYS = (
    "status", "name", "id", "attempts", "changed", "rc", "msg",
    "clusterStatus", "serviceStatus", "state", "clusterName", "environmentName",
    "crn", "url", "message", "error", "failed", "finished", "started",
    "ansible_job_id", "retries",
)

ARRAY_SUMMARY_KEYS = frozenset({
    "database_catalogs", "clusters", "services", "instances", "events",
    "workloads", "users", "groups", "resources",
})

CRN_RE = re.compile(r"^crn:")


def _truncate(text: str, limit: int = 120) -> str:
    if len(text) <= limit:
        return text
    return text[: limit - 3] + "..."


def _short_crn(value: str) -> str:
    if not isinstance(value, str) or not CRN_RE.match(value):
        return value
    tail = value.rsplit("/", 1)[-1]
    return tail if len(tail) < len(value) else _truncate(value, 80)


def _stdout_snippet(value: Any) -> Optional[str]:
    if value is None:
        return None
    if isinstance(value, list):
        if not value:
            return None
        value = value[0]
    if not isinstance(value, str):
        value = str(value)
    line = value.splitlines()[0] if value else ""
    line = line.strip()
    if not line:
        return None
    return _truncate(line, 120)


def _summarize_catalog_item(item: Any) -> str:
    if not isinstance(item, dict):
        return str(item)
    name = item.get("name") or item.get("displayName") or item.get("id")
    status = item.get("status") or item.get("clusterStatus") or item.get("state")
    if status and name:
        return f"{status} ({name})"
    if name:
        return str(name)
    if status:
        return str(status)
    sid = item.get("id")
    return _short_crn(str(sid)) if sid else "?"


def _summarize_array(key: str, arr: List[Any]) -> str:
    if not arr:
        return "0"
    if key == "database_catalogs":
        parts = [_summarize_catalog_item(x) for x in arr[:5]]
        extra = f", +{len(arr) - 5} more" if len(arr) > 5 else ""
        return f"{len(arr)} " + ", ".join(parts) + extra
    if key in ("clusters", "services", "instances", "workloads"):
        parts = [_summarize_catalog_item(x) for x in arr[:3]]
        extra = f", +{len(arr) - 3} more" if len(arr) > 3 else ""
        return f"{len(arr)} " + ", ".join(parts) + extra
    return f"{len(arr)} item(s)"


def _summarize_nested_dict(key: str, val: Dict[str, Any]) -> Any:
    if key in ("cluster", "service", "environment", "dbcatalogstatus"):
        sub: Dict[str, Any] = {}
        for sk in ("status", "name", "id", "clusterStatus", "serviceStatus", "state"):
            if sk in val and not isinstance(val[sk], (dict, list)):
                sub[sk] = val[sk]
        if sub:
            return sub
    inner: Dict[str, Any] = {}
    for sk in SCALAR_KEYS:
        if sk in val and not isinstance(val[sk], (dict, list)):
            inner[sk] = val[sk]
    if inner:
        return inner
    return f"{len(val)} key(s)"


def summarize_ansible_result_obj(obj: Any) -> Any:
    """Return a compact JSON-serializable summary of an Ansible result dict."""
    if not isinstance(obj, dict):
        return obj

    summary: Dict[str, Any] = {}

    for key in SCALAR_KEYS:
        if key not in obj:
            continue
        val = obj[key]
        if isinstance(val, (dict, list)):
            continue
        if isinstance(val, str):
            if key in ("crn",) or CRN_RE.match(val):
                val = _short_crn(val)
            elif key == "msg":
                val = _truncate(val, 160)
            elif key == "cmd":
                val = _truncate(val, 120)
            else:
                val = _truncate(val, 120)
        summary[key] = val

    if "stdout" in obj and "stdout" not in summary:
        snippet = _stdout_snippet(obj.get("stdout"))
        if snippet:
            summary["stdout"] = snippet

    if "stderr" in obj and isinstance(obj.get("stderr"), str) and obj["stderr"].strip():
        summary["stderr"] = _truncate(obj["stderr"].strip().splitlines()[0], 120)

    if "cmd" in obj and "cmd" not in summary:
        cmd = obj["cmd"]
        if isinstance(cmd, list):
            cmd = " ".join(str(x) for x in cmd)
        if cmd:
            summary["cmd"] = _truncate(str(cmd), 120)

    for key, val in obj.items():
        if key in summary or key in SUMMARY_NOISE_KEYS or key.startswith("_ansible"):
            continue
        if key in ("stdout", "stderr", "cmd"):
            continue
        if isinstance(val, list) and key in ARRAY_SUMMARY_KEYS:
            summary[key] = _summarize_array(key, val)
        elif isinstance(val, list) and len(val) > 0:
            summary[key] = _summarize_array(key, val)
        elif isinstance(val, dict):
            summary[key] = _summarize_nested_dict(key, val)

    if not summary:
        for key, val in obj.items():
            if key in SUMMARY_NOISE_KEYS or key.startswith("_ansible"):
                continue
            if isinstance(val, (dict, list)):
                continue
            if isinstance(val, str):
                val = _truncate(val, 120)
            summary[key] = val
            if len(summary) >= 8:
                break

    return summary


def dump_summarized_results(obj: Any, sort_keys: bool = True) -> str:
    return json.dumps(summarize_ansible_result_obj(obj), sort_keys=sort_keys)


# --- skip compaction (parallel deploy console) ---

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


def is_task_failure_line(text: str) -> bool:
    return bool(re.match(r"^(fatal|failed):", text)) or "UNREACHABLE!" in text


def is_task_ok_changed_line(text: str) -> bool:
    return bool(re.match(r"^(ok|changed):", text))


def print_pretty_json(prefix: str, head: str, obj: Any) -> None:
    pretty = json.dumps(obj, indent=4, sort_keys=True)
    plines = pretty.splitlines()
    print(f"{prefix}{head}{plines[0]}")
    for pline in plines[1:]:
        print(f"{prefix}{pline}")


def print_tagged_ansible_log_line(tag: str, line: str) -> None:
    prefix = f"[{tag}] "
    marker = " => "

    if is_task_skip_line(line):
        print(prefix + format_skip_line(line))
        return

    if marker not in line:
        print(prefix + line)
        return

    idx = line.rfind(marker)
    head = line[: idx + len(marker)]
    payload = line[idx + len(marker):].strip()
    if not payload or payload[0] not in "{[":
        print(prefix + line)
        return

    try:
        obj = json.loads(payload)
    except json.JSONDecodeError:
        print(prefix + line)
        return

    if is_task_failure_line(line):
        print_pretty_json(prefix, head, obj)
        return

    if is_task_ok_changed_line(line):
        try:
            summary = summarize_ansible_result_obj(obj)
            print(prefix + head + json.dumps(summary, sort_keys=True))
            return
        except Exception:
            pass

    print_pretty_json(prefix, head, obj)


def main(argv: Optional[List[str]] = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    if not args:
        sys.stderr.write("usage: hol-ansible-log-format.py summarize-json|format-tagged-line ...\n")
        return 2

    cmd = args[0]
    if cmd == "summarize-json":
        raw = args[1] if len(args) > 1 else sys.stdin.read()
        try:
            obj = json.loads(raw)
        except json.JSONDecodeError:
            print(raw.strip(), end="")
            return 1
        print(dump_summarized_results(obj))
        return 0

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
