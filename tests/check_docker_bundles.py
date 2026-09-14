#!/usr/bin/env python3
"""Check OS docker_version_map pins: no bare containerd.io, no 29.0 key."""
from __future__ import print_function

import os
import re
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("PyYAML is required: pip install pyyaml\n")
    sys.exit(2)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))

# Frozen apt pools that cannot use the shared 1.6/1.7/2.x pins.
OS_CONTAINERD_EXCEPTIONS = {
    ("os_Ubuntu_16.yml", "18.09"): "1.4.6-1*",
    ("os_Ubuntu_16.yml", "19.03"): "1.4.6-1*",
    ("os_Ubuntu_18.yml", "19.03"): "1.6.21-1*",
}

CE_PKG = re.compile(r"^(docker-ce(?:-cli)?)[=-](?:5:)?(.+)$")
CONTAINERD_PKG = re.compile(r"^containerd\.io[=-](.+)$")


def load_yaml(path):
    with open(path) as fh:
        return yaml.safe_load(fh)


def containerd_pin(pkgs):
    for pkg in pkgs:
        match = CONTAINERD_PKG.match(pkg)
        if match:
            return match.group(1)
    return None


def docker_pins(pkgs):
    found = {}
    for pkg in pkgs:
        match = CE_PKG.match(pkg)
        if match:
            found[match.group(1)] = match.group(2)
    return found


def main():
    errors = []
    vars_dir = os.path.join(ROOT, "vars")
    ce_keys = 0

    if os.path.exists(os.path.join(vars_dir, "docker_bundles.yml")):
        errors.append("vars/docker_bundles.yml should be removed; pins live in os_*.yml")

    for name in sorted(os.listdir(vars_dir)):
        if not (name.startswith("os_") and name.endswith(".yml")):
            continue
        data = load_yaml(os.path.join(vars_dir, name)) or {}
        version_map = data.get("docker_version_map") or {}
        if "29.0" in version_map:
            errors.append("%s: must not define a 29.0 key" % name)

        for key, entry in version_map.items():
            if not isinstance(entry, dict):
                continue
            if entry.get("method") == "static":
                tarball = entry.get("tarball_version")
                if not tarball:
                    errors.append("%s %s: static install missing tarball_version" % (name, key))
                continue

            pkgs = entry.get("package")
            if not isinstance(pkgs, list):
                continue
            if "containerd.io" in pkgs:
                errors.append("%s %s: bare containerd.io" % (name, key))

            pins = docker_pins(pkgs)
            if "docker-ce" in pins:
                ce_keys += 1
                if pins.get("docker-ce") != pins.get("docker-ce-cli"):
                    errors.append(
                        "%s %s: docker-ce %r and docker-ce-cli %r differ"
                        % (name, key, pins.get("docker-ce"), pins.get("docker-ce-cli"))
                    )
                if key == "29" and pins["docker-ce"] != "29.*":
                    errors.append("%s %s: docker must be latest 29.x (29.*), got %r" % (name, key, pins["docker-ce"]))
                ctd = containerd_pin(pkgs)
                if ctd is None:
                    errors.append("%s %s: docker-ce list has no containerd.io pin" % (name, key))
                expected = OS_CONTAINERD_EXCEPTIONS.get((name, key))
                if expected and ctd != expected:
                    errors.append("%s %s: expected frozen containerd %r, got %r" % (name, key, expected, ctd))

    if errors:
        for err in errors:
            print("FAIL:", err)
        return 1
    print("OK: docker maps pin containerd (%d CE keys)" % ce_keys)
    return 0


if __name__ == "__main__":
    sys.exit(main())
