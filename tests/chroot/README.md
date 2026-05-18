# Chroot Tests

This directory is reserved for future chroot installation tests.

Required before ISO build release work:

- install SoryOS packages into a clean chroot
- run `soryos-install --dry-run`
- verify `soryos-diagnose`
- verify rollback behavior
- prove no Pop!_OS repositories are removed
