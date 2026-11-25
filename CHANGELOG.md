# Changelog

All notable changes to NestroForge are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `nf` now works directly inside Termux. The installer adds a small launcher to Termux's bin folder that runs the root-only tool through `su`, so `su -c "nf ..."` is no longer needed.
  - Only added when Termux is installed; skipped with a clear message otherwise.
  - Never overwrites a different `nf` that is already in Termux.
  - Removed again when the module is uninstalled.
- `nf termux [link|unlink|status]` to manage the Termux command by hand (for example after installing Termux later).
- `ENABLE_TERMUX_LINK` config key (default `1`). `nf apply` and every boot re-create the launcher if Termux data was cleared, or remove it when set to `0`.
- `Termux nf` line in `nf status`.
- `README.md` and `CHANGELOG.md`.

### Changed
- Install and `nf help` messages now point to the plain `nf` command.

## Earlier versions

Features that are already in the module before this release (fill in version numbers and dates from your `module.prop` history):

- Keybox placement into Tricky Store with validation, checksums, atomic writes, backups and a `KEYBOX_OVERWRITE_EXISTING` safety switch.
- Security patch spoofing through `security_patch.txt`.
- Local ADB over localhost with IPv4 and IPv6 firewall rules (off by default).
- Boot-loop protection with automatic self-disable and `nf bootloop reset`.
- Notifications on status changes and problems.
- Live status in the module description.
- Action button menu (Magisk 27+).
- `nf` command line tool and a persistent data folder that survives updates.
