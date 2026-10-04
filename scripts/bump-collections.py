#!/usr/bin/env python3
"""Bump the pinned Ansible collections to the highest version published on Galaxy.

Usage: bump-collections.py [--check] [FILE]

Rewrites the version lines of FILE (default dockerfiles/collections.yml) in place, keeping
comments and order, and prints one line per change. With --check nothing is written and the
exit code is 1 when a newer version exists. Needs only the standard library.
"""
import json
import re
import sys
import urllib.request

GALAXY = "https://galaxy.ansible.com/api/v3/plugin/ansible/content/published/collections/index/{ns}/{name}/"
NAME_RE = re.compile(r"^(\s*)- name:\s*([\w.]+)\s*$")
VERSION_RE = re.compile(r"^(\s*version:\s*)(\S+)\s*$")


def highest_version(collection):
    namespace, name = collection.split(".", 1)
    with urllib.request.urlopen(GALAXY.format(ns=namespace, name=name), timeout=30) as response:
        return json.load(response)["highest_version"]["version"]


def main(argv):
    check = "--check" in argv
    args = [a for a in argv if a != "--check"]
    path = args[0] if args else "dockerfiles/collections.yml"

    lines = open(path).read().splitlines(keepends=True)
    current = None
    changes = []
    for index, line in enumerate(lines):
        name_match = NAME_RE.match(line)
        if name_match:
            current = name_match.group(2)
            continue
        version_match = VERSION_RE.match(line)
        if version_match and current:
            old = version_match.group(2)
            new = highest_version(current)
            if new != old:
                changes.append((current, old, new))
                lines[index] = f"{version_match.group(1)}{new}\n"
            current = None

    for collection, old, new in changes:
        print(f"{collection}: {old} -> {new}")
    if not changes:
        print("all collections are at their highest published version")
        return 0
    if check:
        return 1
    open(path, "w").write("".join(lines))
    print(f"updated {path}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
