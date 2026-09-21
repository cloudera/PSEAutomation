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

hol_patch_cdpcli_shorthand() {
   python3 <<'PY'
import pathlib
import re

try:
    import cdpcli.shorthand as mod
except ImportError:
    raise SystemExit(0)

path = pathlib.Path(mod.__file__)
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
    print(f"hol-patch: fixed cdpcli shorthand escapes in {path}")
PY
}

hol_patch_cdp_service
hol_patch_cdpcli_shorthand
