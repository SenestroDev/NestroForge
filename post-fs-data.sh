#!/system/bin/sh
# post-fs-data.sh - runs in post-fs-data mode (BLOCKING)
# WARNING: Boot is paused until this finishes or 40 seconds pass
# WARNING: Use resetprop -n instead of setprop to avoid deadlock
# Only use this if absolutely necessary

MODDIR="${0%/*}"

# Your script here

