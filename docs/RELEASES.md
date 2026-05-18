# SoryOS Release Channels

SoryOS will use three APT suites:

- `stable`: tested packages for normal systems and ISO releases.
- `testing`: integration testing before stable promotion.
- `nightly`: automated builds and early validation.

Current published suite:

```text
stable
testing
nightly
```

Target layout:

```text
dists/stable/main/binary-amd64/Packages.gz
dists/testing/main/binary-amd64/Packages.gz
dists/nightly/main/binary-amd64/Packages.gz
pool/stable/*.deb
pool/testing/*.deb
pool/nightly/*.deb
```

Rules:

- ISO releases must consume `stable` by default.
- `testing` and `nightly` must never be enabled on stable systems unless explicitly requested.
- Every package version must increase when moving between published builds.
- SoryOS packages must not depend directly on Pop!_OS-only package names unless the package is explicitly marked as a migration bridge.
