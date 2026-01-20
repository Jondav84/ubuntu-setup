#!/usr/bin/env bash
set -euo pipefail

# Detect active monitors
xrandr --query

# Your current known outputs (from your earlier xrandr list):
# HDMI-1 (external)
# eDP-1 (laptop panel)
# DVI-I-1 (Displaylink adapter)
#
# Layout strategy:
# - HDMI-1 as primary on the left
# - eDP-1 to the right of HDMI-1
# - DVI-I-1 to the right of eDP-1

xrandr \
--output HDMI-1 --mode 1920x1080 --pos 0x0 --primary \
--output eDP-1 --mode 1920x1080 --pos 1920x0 \
--output DVI-I-1 --mode 1366x768 --pos 3840x312
