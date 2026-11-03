#!/usr/bin/env bash
# Cloud environment setup for Scrap Heist.
#
# Paste this into the cloud environment's "Setup script" setting, or run it
# with `bash scripts/cloud-setup.sh`. It runs as root on Ubuntu when a new
# session starts, and is safe to run more than once.

set -euo pipefail

# ripgrep and sd for searching and editing (CLAUDE.md asks for them over grep
# and sed), ffmpeg for MP4 turntables, and a virtual desktop (Xvfb + Openbox)
# for GUI apps (see scripts/desktop.sh).
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
	ca-certificates curl ripgrep sd \
	xvfb x11-utils xdotool imagemagick openbox mesa-utils ffmpeg \
	>/dev/null

# Start the virtual 1920x1080 desktop on :99. Inlined rather than calling
# scripts/desktop.sh, since the repo may not be cloned yet when this runs.
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
	nohup Xvfb :99 -screen 0 1920x1080x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
	for _ in $(seq 50); do
		xdpyinfo -display :99 >/dev/null 2>&1 && break
		sleep 0.1
	done
	DISPLAY=:99 nohup openbox >/tmp/openbox.log 2>&1 &
fi
