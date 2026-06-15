#!/system/bin/sh
# service.sh - runs in late_start service mode (NON-BLOCKING)
# This is the recommended place for most boot scripts
# Use: MODDIR=${0%/*} to get your module's directory

MODDIR="${0%/*}"

# Your script here

# Wait for system to fully boot before applying settings.
# 'settings put' requires the system settings provider to be ready,
# which isn't guaranteed at early boot — 30s is a safe margin.
sleep 30

# Disable Android 13's GATT robust caching.
# Robust caching was introduced in Android 12/13 and causes Android to
# reject BLE devices whose GATT service cache doesn't match expectations.
# This breaks BT5.x mice and other HID devices with non-standard GAP
# implementations, causing them to disconnect after ~5-30 seconds.
settings put global bluetooth_gatt_robust_caching_enabled 0

# Disable GATT robust caching via persist prop (belt-and-suspenders).
# The 'settings put' above covers the runtime value; this persist prop
# ensures the BT stack itself also respects the disabled state across
# bluetooth restarts without requiring a full reboot.
setprop persist.bluetooth.gatt.enable_robust_caching false

# Disable Enhanced ATT (eATT) bearer negotiation.
# Android 13 enables eATT by default for BT5.x devices, pushing an
# enhanced GATT channel during connection setup. BLE mice that advertise
# BT5.2 but don't fully implement eATT get stuck in negotiation and drop.
# Disabling forces the classic ATT bearer, which all HID devices support.
setprop persist.bluetooth.gatt.eatt.enabled false
