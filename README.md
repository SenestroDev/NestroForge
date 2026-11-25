# NestroForge

A Magisk module that keeps your Tricky Store setup in order: it places your `keybox.xml`, spoofs the security patch level, optionally opens ADB on localhost for Termux, and protects you from boot loops. Everything is controlled with one command, `nf`.

## Features

- **Keybox management**: copies your keybox into Tricky Store at boot, only when it changed, with a sanity check and `0600` permissions. A keybox the module did not write is backed up before it is replaced.
- **Security patch spoofing**: writes `security_patch.txt` for Tricky Store from a single config value.
- **Local ADB (off by default)**: adbd listens on localhost only, and the port is firewalled for both IPv4 and IPv6. If the firewall rules cannot be applied, ADB stays closed.
- **Boot-loop protection**: after too many unfinished boots the module disables itself.
- **Notifications**: a message after boot only when the status changed or something needs attention.
- **Live status** in the module description inside the Magisk app.
- **Action button** (Magisk 27+): a small volume-key menu for status, log and re-apply.
- **`nf` command line tool**, also available directly inside Termux.

## Requirements

- Magisk 24.0 or newer (27+ for the Action button)
- [Tricky Store](https://github.com/5ec1cff/TrickyStore) installed (the module warns if it is missing)
- Install from the Magisk app. Installing from recovery is blocked on purpose.

## Install

1. Flash the zip in the Magisk app (Modules, Install from storage).
2. Put your keybox at `/data/adb/NestroForge/keybox.xml` (or bundle one in the zip).
3. Reboot.

Updating is the same: flash the new zip. Your config, keybox and logs in `/data/adb/NestroForge` are kept.

## Using `nf`

In Termux, just type the command. The module adds a small launcher to Termux that calls the real tool through `su`, so Termux will ask for root the first time.

```
nf status                      show everything
nf log [lines]                 last log lines (default 20)
nf apply                       re-apply keybox, patch, ADB, Termux command, description

nf keybox [apply|status|path]
nf patch  [show|set YYYY-MM-DD|off]
nf adb    [on|off|status]
nf termux [link|unlink|status]
nf notify [on|off|sample]
nf bootloop [status|reset]
nf config [show|set KEY VALUE]
```

Without the launcher (or from any other root shell): `su -c "nf status"`.

### How the Termux command works

`/data/adb` is root-only, so a plain symlink from Termux to the real `nf` would only give "Permission denied". Instead the module writes a tiny launcher script to `/data/data/com.termux/files/usr/bin/nf` (with Termux's owner and SELinux label). It is only created when Termux is installed, it never overwrites a different `nf` you already have, and it is removed when the module is uninstalled.

If Termux was installed but never opened during install, open it once and run `su -c "nf termux link"` (or just reboot). To turn the feature off, set `ENABLE_TERMUX_LINK=0`.

## Configuration

File: `/data/adb/NestroForge/config.sh` (plain shell, `KEY=value`). Apply with `nf apply` or a reboot. New keys are added automatically on update; your values are never overwritten.

| Key | Default | Meaning |
|-----|---------|---------|
| `ENABLE_KEYBOX` | `1` | Copy the keybox into Tricky Store at boot |
| `KEYBOX_OVERWRITE_EXISTING` | `0` | Let a bundled keybox replace a Tricky Store keybox this module did not write (the old one is backed up) |
| `ENABLE_ADB_LOCAL` | `0` | ADB over TCP on localhost only |
| `ADB_LOCAL_PORT` | `5555` | Port for local ADB (1024-65535) |
| `ENABLE_DESCRIPTION` | `1` | Live status in the Magisk module description |
| `ENABLE_TERMUX_LINK` | `1` | Keep the `nf` command available in Termux |
| `SECURITY_PATCH` | empty | Spoofed patch level, `YYYY-MM-DD` (empty = off) |
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
| `/data/adb/NestroForge/bin/nf` | The CLI |

## Uninstall

Remove the module in the Magisk app and reboot. This removes the Termux `nf` launcher and the local ADB setting (only if this module enabled it). Your files in `/data/adb/NestroForge` and the keybox already copied into Tricky Store are left in place; delete them by hand for a full cleanup.

## Troubleshooting

- **`nf: not found` in Termux**: run `su -c "nf termux status"`. `absent` means Termux is not installed, `not-initialised` means open Termux once and run `su -c "nf termux link"`, `foreign` means another `nf` is already in Termux and was left alone.
- **Module disabled itself**: boot-loop protection tripped. Re-enable it in Magisk or run `su -c "nf bootloop reset"`.
- **Local ADB shows `blocked`**: the IPv4 or IPv6 firewall rule could not be applied, so ADB was deliberately kept closed. Check `nf log`.
- **Keybox shows `invalid`**: the file is truncated or not a keybox, so it was not applied.

## Security notes

- The keybox contains private keys. Keep it out of backups and public repositories.
- Any app on the phone can reach `127.0.0.1:<port>` when local ADB is on. Never tick "Always allow" in the debugging prompt for something you do not trust.
