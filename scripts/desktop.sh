#!/usr/bin/env bash
# Virtual 1920x1080 desktop for running GUI apps (Blender) in the cloud.
#
#   scripts/desktop.sh start            start the desktop on :99 (no-op if running)
#   scripts/desktop.sh screenshot FILE  save a PNG of the whole screen
#   scripts/desktop.sh stop
#
# Run GUI apps with DISPLAY=:99.

set -euo pipefail

DISPLAY_NUM=":99"
RESOLUTION="1920x1080x24"
LOG_DIR="${TMPDIR:-/tmp}/scrap-heist-desktop"

running() {
	xdpyinfo -display "${DISPLAY_NUM}" >/dev/null 2>&1
}

case "${1:-}" in
	start)
		if running; then
			exit 0
		fi
		mkdir -p "${LOG_DIR}"
		nohup Xvfb "${DISPLAY_NUM}" -screen 0 "${RESOLUTION}" -nolisten tcp >"${LOG_DIR}/xvfb.log" 2>&1 &
		for _ in $(seq 50); do
			running && break
			sleep 0.1
		done
		running || { echo "Xvfb failed to start, see ${LOG_DIR}/xvfb.log" >&2; exit 1; }
		# A window manager so windows get placed, focused and maximized.
		DISPLAY="${DISPLAY_NUM}" nohup openbox >"${LOG_DIR}/openbox.log" 2>&1 &
		;;
	screenshot)
		import -display "${DISPLAY_NUM}" -window root "${2:?usage: desktop.sh screenshot FILE}"
		;;
	stop)
		pkill -f "Xvfb ${DISPLAY_NUM}" || true
		;;
	*)
		echo "usage: desktop.sh start|screenshot FILE|stop" >&2
		exit 1
		;;
esac
