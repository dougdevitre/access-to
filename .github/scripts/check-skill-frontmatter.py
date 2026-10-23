#!/usr/bin/env python3
"""Validate a SKILL.md against the claude.ai upload rules.

Vendored into the hub from the 2026-10-23 launch QA (scratchpad
skill-check/check-skill-frontmatter.py) so ecosystem-zip-check.sh can run the
same checks on every published install zip. Keep the two in step.

Rules (primary sources, checked 2026-10-20):
  https://platform.claude.com/docs/agents-and-tools/agent-skills/overview
    name: required, <=64 chars, lowercase letters/numbers/hyphens only,
          no XML tags, must not contain "anthropic" or "claude"
    description: required, non-empty, <=1024 chars, no XML tags
  https://support.claude.com/en/articles/12512180-use-skills-in-claude
    upload fails if the skill folder name doesn't match the skill name

Usage: check-skill-frontmatter.py path/to/SKILL.md [expected-folder-name]
Exits 1 on any violation, printing one line per problem.
"""
import re
import sys

try:
    import yaml
except ImportError:  # pragma: no cover
    sys.exit("PyYAML is required: pip install pyyaml")


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    path = sys.argv[1]
    folder = sys.argv[2] if len(sys.argv) > 2 else None
    text = open(path, encoding="utf-8").read()
    m = re.match(r"---\r?\n(.*?)\r?\n---\r?\n", text, re.S)
    if not m:
        print(f"{path}: no YAML frontmatter at the top of the file")
        return 1
    try:
        fm = yaml.safe_load(m.group(1)) or {}
    except yaml.YAMLError as e:
        print(f"{path}: frontmatter is not valid YAML: {e}")
        return 1

    errs = []
    name = fm.get("name")
    desc = fm.get("description")
    xml = re.compile(r"<[^>]+>")

    if not isinstance(name, str) or not name:
        errs.append("name is missing")
    else:
        if len(name) > 64:
            errs.append(f"name is {len(name)} chars (max 64)")
        if not re.fullmatch(r"[a-z0-9-]+", name):
            errs.append("name may only use lowercase letters, numbers and hyphens")
        if re.search(r"anthropic|claude", name):
            errs.append('name must not contain "anthropic" or "claude"')
        if folder and folder != name:
            errs.append(f'skill folder "{folder}" must match name "{name}"')

    if not isinstance(desc, str) or not desc.strip():
        errs.append("description is missing or empty")
    else:
        if len(desc) > 1024:
            errs.append(f"description is {len(desc)} chars (max 1024)")
        if xml.search(desc):
            errs.append("description must not contain XML tags")

    for e in errs:
        print(f"{path}: {e}")
    if not errs:
        print(f"{path}: OK (name={name}, description={len(desc)} chars)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
