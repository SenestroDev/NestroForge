# Changelog

All notable changes to NestroForge are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.7.0] - 2026-11-27

### Added
- `nf` works directly inside Termux. The installer adds a small launcher to Termux's bin folder that runs the root-only tool through `su`, so `su -c "nf ..."` is no longer needed.
  - Only added when Termux is installed; never overwrites a different `nf`; removed again on uninstall.
- `nf termux [link|unlink|status]`, the `ENABLE_TERMUX_LINK` key and a `Termux nf` line in `nf status`.
- `nf doctor`: checks root manager, SELinux, config, Tricky Store, target apps, keybox (structure, permissions, certificate expiry when `openssl` exists), patch, local ADB (firewall rule, adbd, watchdog), Termux and the boot guard.
- `nf target [list|add|remove|path]`: manage Tricky Store's `target.txt`.
- `nf backup [file] [--with-keybox]` and `nf restore FILE`. A restore refuses archives with unexpected files or config lines that are not plain `KEY=value`, and keeps the old files in `backup/`.
- `nf log export [file]`: saves status, doctor output and the log in one report (no key material).
- `nf config check`: validates every value in `config.sh` without executing it.
- `SECURITY_PATCH=auto` follows the device's own patch level.
- Local ADB firewall watchdog (`ADB_WATCHDOG`, default `1`): re-checks the firewall rule every 60 s, restores it, and closes ADB again if that fails.
- Action menu: run doctor, turn local ADB on/off, reset boot guard, send test notification.
- `updateJson` in `module.prop` plus `update.json`, so the root manager shows updates.
- `build.sh` (builds the zip and refreshes `update.json`) and a GitHub Actions release workflow.
- KernelSU and APatch support in the installer; `resetprop` falls back to `setprop`.
- `README.md` and `CHANGELOG.md`.

### Changed
- Install and `nf help` messages point to the plain `nf` command.
- The Action menu polls the volume at 0.3 s instead of 0.1 s (much less CPU).
- The `system.prop` / MT6768 warning is only shown when the zip actually contains a `system.prop`.
- The "Action button not available" and "Magisk 24 required" checks only apply to real Magisk (KernelSU and APatch report a fake Magisk version).

### Fixed
- Local ADB: if the firewall rule could not be re-applied while ADB over TCP was already open, the port stayed open to the network. It is now closed and the status shows `blocked`.
- Local ADB: changing `ADB_LOCAL_PORT` and running `nf apply` was ignored. The old port is now closed and the new one opened.
- Keybox status no longer goes stale after `ENABLE_KEYBOX=0` (it now shows `disabled`).
- A patch `error` status now counts as a problem in the notification and module description.
- `nf patch set` with no date no longer silently turns spoofing off, and `nf config set KEY` with no value is refused.
- `nf config set` validates values (0/1 switches, port range, numbers, patch format).
- `SECURITY_PATCH` rejects dates that do not exist (for example 2026-02-31).
- `nf termux link` / `unlink` also set `ENABLE_TERMUX_LINK`, so the next boot or `nf apply` does not undo them.

## Before 1.7.0

- Keybox placement into Tricky Store with validation, checksums, atomic writes, backups and a `KEYBOX_OVERWRITE_EXISTING` safety switch.
- Security patch spoofing through `security_patch.txt`.
- Local ADB over localhost with IPv4 and IPv6 firewall rules (off by default).
- Boot-loop protection with automatic self-disable and `nf bootloop reset`.
- Notifications on status changes and problems.
- Live status in the module description.
- Action button menu.
- `nf` command line tool and a persistent data folder that survives updates.
