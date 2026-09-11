#!/usr/bin/env python3
"""Check docker_bundles + OS maps: no bare containerd.io, keys align."""
from __future__ import print_function

import os
import sys

try:
    import yaml
except ImportError:
    sys.stderr.write("PyYAML is required: pip install pyyaml\n")
    sys.exit(2)

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(ROOT, "filter_plugins"))
from docker_bundle import docker_bundle_packages  # noqa: E402


def load_yaml(path):
    with open(path) as fh:
        return yaml.safe_load(fh)


def main():
    errors = []
    bundles = load_yaml(os.path.join(ROOT, "vars", "docker_bundles.yml"))["docker_bundles"]
    vars_dir = os.path.join(ROOT, "vars")

    by_key = {}
    for name in sorted(os.listdir(vars_dir)):
        if not (name.startswith("os_") and name.endswith(".yml")):
            continue
        data = load_yaml(os.path.join(vars_dir, name)) or {}
        version_map = data.get("docker_version_map") or {}
        for key, entry in version_map.items():
            if not isinstance(entry, dict):
                continue
            if "package" in entry and isinstance(entry["package"], list):
                if "containerd.io" in entry["package"]:
                    errors.append("%s %s: hardcoded bare containerd.io" % (name, key))
            style = entry.get("pkg_style")
            if style not in ("apt", "yum"):
                continue
            if key not in bundles:
                errors.append("%s %s: pkg_style=%s but no docker_bundles entry" % (name, key, style))
                continue
            try:
                pkgs = docker_bundle_packages(entry, bundles, key)
            except Exception as exc:
                errors.append("%s %s: render failed: %s" % (name, key, exc))
                continue
            if "containerd.io" in pkgs:
                errors.append("%s %s: rendered bare containerd.io: %s" % (name, key, pkgs))
            containerd = entry.get("containerd", bundles[key].get("containerd"))
            by_key.setdefault(key, []).append((name, containerd, entry.get("containerd") is not None))

    for key, rows in sorted(by_key.items()):
        default = bundles[key].get("containerd")
        for name, containerd, overridden in rows:
            if overridden:
                continue
            if containerd != default:
                errors.append(
                    "%s %s: containerd %r does not match bundle %r and has no override"
                    % (name, key, containerd, default)
                )

    docker29 = bundles.get("29", {}).get("docker", "")
    if docker29 != "29.*":
        errors.append("docker_bundles['29'].docker must be latest 29.x (29.*), got %r" % (docker29,))

    if "29.0" in bundles:
        errors.append("docker_bundles must not define 29.0")

    if errors:
        for err in errors:
            print("FAIL:", err)
        return 1
    print("OK: docker bundles align (%d CE keys)" % len(by_key))
    return 0


if __name__ == "__main__":
    sys.exit(main())
