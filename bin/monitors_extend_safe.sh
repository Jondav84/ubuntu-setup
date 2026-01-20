#!/usr/bin/env bash
set -euo pipefail

# Desired layout (matches GNOME display diagram):
# Top row: HDMI-1 (Display 2) left, DVI-I-1 (Display 3) right
# Bottom row: eDP-1 (Display 1) centered under the top row

# Resolutions (from your system):
# HDMI-1  = 1920x1080
# DVI-I-1 = 1366x768
# eDP-1   = 1920x1080

TOP_LEFT_W=1920
TOP_LEFT_H=1080

TOP_RIGHT_W=1366
TOP_RIGHT_H=768

BOTTOM_W=1920
BOTTOM_H=1080

# Total top width
TOP_TOTAL_W=$((TOP_LEFT_W + TOP_RIGHT_W))

# Center bottom under top row:
# bottom_x = (top_total_width - bottom_width) / 2
BOTTOM_X=$(((TOP_TOTAL_W - BOTTOM_W) / 2))
BOTTOM_Y=${TOP_LEFT_H}

xrandr \
  --output HDMI-1  --mode ${TOP_LEFT_W}x${TOP_LEFT_H} --pos 0x0 --primary \
  --output DVI-I-1 --mode ${TOP_RIGHT_W}x${TOP_RIGHT_H} --pos ${TOP_LEFT_W}x0 \
  --output eDP-1   --mode ${BOTTOM_W}x${BOTTOM_H} --pos ${BOTTOM_X}x${BOTTOM_Y}
