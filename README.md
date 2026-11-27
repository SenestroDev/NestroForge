# NestroForge

A root module (Magisk, KernelSU or APatch) that keeps your Tricky Store setup in order: it places your `keybox.xml`, spoofs the security patch level, manages the target app list, optionally opens ADB on localhost for Termux, and protects you from boot loops. Everything is controlled with one command, `nf`.

## Features

- **Keybox management**: copies your keybox into Tricky Store at boot, only when it changed, with a sanity check and `0600` permissions. A keybox the module did not write is backed up before it is replaced.
- **Security patch spoofing**: writes `security_patch.txt` from one config value (a date, or `auto` for the device's own level).
- **Target apps**: `nf target add|remove|list` edits Tricky Store's `target.txt`.
- **Local ADB (off by default)**: adbd listens on localhost only; the port is firewalled for IPv4 and IPv6, and a watchdog keeps the rule in place. If the rule cannot be applied or restored, ADB is closed.
- **Doctor**: `nf doctor` checks the whole setup and tells you what to fix.
- **Backup and restore** of your config (and optionally the keybox).
- **Boot-loop protection**: after too many unfinished boots the module disables itself.
- **Notifications** after boot, only when the status changed or something needs attention.
- **Live status** in the module description.
- **Action button**: a volume-key menu (status, log, re-apply, doctor, local ADB on/off, boot guard reset, test notification).
- **Update notifications** in the root manager (`updateJson`).
- **`nf` inside Termux**, no `su -c` needed.

## Requirements

- Magisk 24.0+ (27+ for the Action button), or KernelSU / APatch
- [Tricky Store](https://github.com/5ec1cff/TrickyStore) installed (the module warns if it is missing)
- Install from the root manager app. Installing from recovery is blocked on purpose.

## Install

1. Flash the zip in the root manager app (Magisk: Modules, Install from storage).
2. Put your keybox at `/data/adb/NestroForge/keybox.xml` (or bundle one in the zip).
3. Reboot, then run `nf doctor` in Termux.

Updating is the same: flash the new zip. Your config, keybox and logs in `/data/adb/NestroForge` are kept.

## Using `nf`

In Termux, just type the command. The module adds a small launcher that calls the real tool through `su`, so Termux will ask for root the first time.

```
nf status                      show everything
nf doctor                      check the whole setup and suggest fixes
nf log [lines]                 last log lines (default 20)
nf log export [file]           save status + doctor + log as one report to share
nf apply                       re-apply keybox, patch, ADB, Termux command, description

nf keybox [apply|status|path]
nf patch  [show|set YYYY-MM-DD|auto|off]
nf target [list|add PKG...|remove PKG...|path]
nf adb    [on|off|status]
nf termux [link|unlink|status]
nf notify [on|off|sample]
nf bootloop [status|reset]
nf backup [file] [--with-keybox]
nf restore FILE
nf config [show|check|set KEY VALUE]
```

Without the launcher (or from any other root shell): `su -c "nf status"`.

### Target apps

```
nf target add com.example.bank com.example.wallet!
nf target remove com.example.bank
nf target list
```

Packages are written to `/data/adb/tricky_store/target.txt`. A trailing `!` or `?` is passed through as Tricky Store defines it. Adding a package that is already listed with another suffix replaces the line. Comments in the file are kept.

### Backup and restore

`nf backup` saves `config.sh` to `/data/adb/NestroForge/exports/` (root-only). `--with-keybox` adds the keybox, which holds private keys: keep that file private and do not put it in shared storage. `nf restore FILE` only accepts archives that contain `config.sh` and/or `keybox.xml`, and only config lines of the form `KEY=value`. The files it replaces are kept in `backup/`.

### How the Termux command works

`/data/adb` is root-only, so a plain symlink from Termux to the real `nf` would only give "Permission denied". Instead the module writes a tiny launcher script to `/data/data/com.termux/files/usr/bin/nf` (with Termux's owner and SELinux label). It is only created when Termux is installed, it never overwrites a different `nf` you already have, and it is removed when the module is uninstalled.

If Termux was installed but never opened during install, open it once and run `su -c "nf termux link"` (or just reboot). To turn the feature off, run `nf termux unlink` or set `ENABLE_TERMUX_LINK=0`.

## Configuration

File: `/data/adb/NestroForge/config.sh` (plain shell, `KEY=value`). Apply with `nf apply` or a reboot. Check it with `nf config check`. New keys are added automatically on update; your values are never overwritten.

| Key | Default | Meaning |
|-----|---------|---------|
| `ENABLE_KEYBOX` | `1` | Copy the keybox into Tricky Store at boot |
| `KEYBOX_OVERWRITE_EXISTING` | `0` | Let a bundled keybox replace a Tricky Store keybox this module did not write (the old one is backed up) |
| `ENABLE_ADB_LOCAL` | `0` | ADB over TCP on localhost only |
| `ADB_LOCAL_PORT` | `5555` | Port for local ADB (1024-65535) |
| `ADB_WATCHDOG` | `1` | Re-check the ADB firewall rule every 60 s while local ADB is on |
| `ENABLE_DESCRIPTION` | `1` | Live status in the module description |
| `ENABLE_TERMUX_LINK` | `1` | Keep the `nf` command available in Termux |
| `SECURITY_PATCH` | empty | Spoofed patch level: `YYYY-MM-DD`, `auto` (device's own), or empty = off |
| `ENABLE_NOTIFICATIONS` | `1` | Notify when the status changes or needs attention |
| `BOOTLOOP_PROTECTION` | `1` | Disable the module after too many unfinished boots |
| `BOOTLOOP_MAX` | `2` | Unfinished boots allowed in a row |

## Files

| Path | Purpose |
|------|---------|
| `/data/adb/NestroForge/config.sh` | Your settings |
| `/data/adb/NestroForge/keybox.xml` | Your keybox (always wins over a bundled one) |
| `/data/adb/NestroForge/NestroForge.log` | Log, rotated at about 100 KB |
| `/data/adb/NestroForge/backup/` | Backups of files this module replaced |
| `/data/adb/NestroForge/exports/` | Output of `nf backup` and `nf log export` |
| `/data/adb/NestroForge/bin/nf` | The CLI |

## Uninstall

Remove the module in the root manager app and reboot. This removes the Termux `nf` launcher and the local ADB setting (only if this module enabled it). Your files in `/data/adb/NestroForge` and the keybox already copied into Tricky Store are left in place; delete them by hand for a full cleanup.

## Building a release

```
./build.sh
```

Builds `dist/NestroForge-<version>.zip` (needs `zip`; the repo must contain `META-INF/`) and refreshes `update.json` from `module.prop`. To release: bump `version` and `versionCode` in `module.prop`, add a section to `CHANGELOG.md`, commit, then push a tag that matches the version (for example `v1.7.0`). The GitHub Actions workflow builds the zip and publishes the release; the root manager picks it up through `updateJson`.

## Troubleshooting

Start with `nf doctor`. If you ask for help, attach the output of `nf log export`.

- **`nf: not found` in Termux**: run `su -c "nf termux status"`. `absent` means Termux is not installed, `not-initialised` means open Termux once and run `su -c "nf termux link"`, `foreign` means another `nf` is already in Termux and was left alone.
- **Module disabled itself**: boot-loop protection tripped. Re-enable it in the root manager or run `su -c "nf bootloop reset"`.
- **Local ADB shows `blocked`**: the IPv4 or IPv6 firewall rule could not be applied (or restored by the watchdog), so ADB was deliberately kept closed. Check `nf log`.
- **Keybox shows `invalid`**: the file is truncated or not a keybox, so it was not applied.

## Security notes

- The keybox contains private keys. Keep it out of backups and public repositories.
- Any app on the phone can reach `127.0.0.1:<port>` when local ADB is on. Never tick "Always allow" in the debugging prompt for something you do not trust.
