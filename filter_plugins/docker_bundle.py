try:
    from ansible.errors import AnsibleFilterError
except ImportError:
    class AnsibleFilterError(Exception):
        pass


def _apt_docker(pin):
    if any(c in pin for c in "*~"):
        return pin
    return pin + "*"


def _apt_containerd(pin):
    if pin.startswith("containerd.io"):
        return pin
    if any(c in pin for c in "*~="):
        return "containerd.io=" + pin
    return "containerd.io=" + pin + "*"


def docker_bundle_packages(entry, bundles, version):
    """Render docker-ce / docker-ce-cli / containerd.io from docker_bundles.

    OS map entries with pkg_style apt|yum must not ship a package list.
    Other entries (zypper string, RH 1.13) are returned unchanged.
    """
    if not isinstance(entry, dict):
        return entry

    style = entry.get("pkg_style")
    if style not in ("apt", "yum"):
        return entry.get("package")

    if version not in bundles:
        raise AnsibleFilterError("No docker_bundles entry for %r" % (version,))

    bundle = bundles[version]
    docker = entry.get("docker", bundle.get("docker"))
    containerd = entry.get("containerd", bundle.get("containerd"))
    if not docker:
        raise AnsibleFilterError("docker pin missing for %r" % (version,))
    if not containerd:
        raise AnsibleFilterError(
            "containerd pin missing for %r (bare containerd.io is not allowed)"
            % (version,)
        )

    if style == "apt":
        return [
            "docker-ce=5:" + _apt_docker(docker),
            "docker-ce-cli=5:" + _apt_docker(docker),
            _apt_containerd(containerd),
        ]

    containerd_pkg = (
        containerd if containerd.startswith("containerd.io") else "containerd.io-" + containerd
    )
    return [
        "docker-ce-" + docker,
        "docker-ce-cli-" + docker,
        containerd_pkg,
    ]


class FilterModule(object):
    def filters(self):
        return {"docker_bundle_packages": docker_bundle_packages}
