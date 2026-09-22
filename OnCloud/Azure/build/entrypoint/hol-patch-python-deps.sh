#!/bin/bash
# Patch third-party Python deps for SyntaxWarning-free Ansible module runs (Python 3.12+).
set -euo pipefail

hol_patch_cdp_service() {
   local f
   while IFS= read -r f; do
      [[ -f "$f" ]] || continue
      if grep -q 'SEMVER = re.compile("(\\d+' "$f" 2>/dev/null; then
         sed -i 's/SEMVER = re.compile("(\\d+/SEMVER = re.compile(r"(\\d+/' "$f"
         echo "hol-patch: fixed SEMVER raw string in $f"
      fi
   done < <(find /root/.ansible/collections/ansible_collections/cloudera/cloud -name 'cdp_service.py' 2>/dev/null || true)
}

hol_patch_cdp_de() {
   python3 <<'PY'
import pathlib
import re
import sys

roots = [
    pathlib.Path("/root/.ansible/collections/ansible_collections/cloudera/cloud"),
]
for root in roots:
    if not root.is_dir():
        continue
    for path in root.rglob("cdp_de.py"):
        text = path.read_text(encoding="utf-8")
        orig = text
        text, n = re.subn(
            r'f"Invalid service name: \{name\}\. Must match regex: \^\[a-zA-Z\]\[a-zA-Z0-9\\-\\.\]\+\[a-zA-Z0-9\]\$"',
            r'f"Invalid service name: {name}. Must match regex: ^[a-zA-Z][a-zA-Z0-9\\\\-\\\\.]+[a-zA-Z0-9]$"',
            text,
            count=1,
        )
        if text != orig:
            path.write_text(text, encoding="utf-8")
            cache = path.parent / "__pycache__"
            if cache.is_dir():
                for pyc in cache.glob("cdp_de*.pyc"):
                    try:
                        pyc.unlink()
                    except OSError:
                        pass
            print(f"hol-patch: fixed CDE name regex f-string in {path}")
        elif "Must match regex:" in orig and "[a-zA-Z0-9\\-\\.]" not in orig:
            if re.search(r'\[a-zA-Z0-9\\-\.\]', orig):
                print(
                    f"hol-patch: cdp_de.py still has invalid f-string escapes (no match): {path}",
                    file=sys.stderr,
                )
PY
}

hol_patch_cdpcli_shorthand() {
   python3 <<'PY'
import importlib.util
import pathlib
import re
import sys

spec = importlib.util.find_spec("cdpcli")
if spec is None or not spec.origin:
    raise SystemExit(0)

path = pathlib.Path(spec.origin).resolve().parent / "shorthand.py"
if not path.is_file():
    raise SystemExit(0)

text = path.read_text(encoding="utf-8")
orig = text

def sub_line(name, replacement):
    global text
    text, n = re.subn(
        rf"^(\s*){name} = u'.+'$",
        lambda m: m.group(1) + replacement,
        text,
        count=1,
        flags=re.M,
    )
    return n

sub_line(
    "_START_WORD",
    "_START_WORD = r'\\!\\#-&\\(-\\+\\--\\<\\>-Z\\\\-z' + '\\u007c-\\uffff'",
)
sub_line(
    "_FIRST_FOLLOW_CHARS",
    "_FIRST_FOLLOW_CHARS = r'\\s\\!\\#-&\\(-\\+\\--\\\\\\^-\\|~-' + '\\uffff'",
)
sub_line(
    "_SECOND_FOLLOW_CHARS",
    "_SECOND_FOLLOW_CHARS = r'\\s\\!\\#-&\\(-\\+\\--\\<\\>-' + '\\uffff'",
)

if text != orig:
    path.write_text(text, encoding="utf-8")
    cache = path.parent / "__pycache__"
    if cache.is_dir():
        for pyc in cache.glob("shorthand*.pyc"):
            try:
                pyc.unlink()
            except OSError:
                pass
    print(f"hol-patch: fixed cdpcli shorthand escapes in {path}")
elif any(" = u'" in line for line in orig.splitlines() if "_START_WORD" in line or "_FIRST_FOLLOW_CHARS" in line or "_SECOND_FOLLOW_CHARS" in line):
    print("hol-patch: cdpcli shorthand still has u'' regex constants (no match)", file=sys.stderr)
PY
}

hol_patch_cdp_service
hol_patch_cdp_de
hol_patch_cdpcli_shorthand
