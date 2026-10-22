#!/usr/bin/env bash
# Cloud environment setup for Scrap Heist.
#
# Paste this into the cloud environment's "Setup script" setting, or run it
# with `bash scripts/cloud-setup.sh`. It runs as root on Ubuntu when a new
# session starts, and is safe to run more than once.

set -euo pipefail

BLENDER_VERSION="5.2.2"
BLENDER_SERIES="${BLENDER_VERSION%.*}"
BLENDER_SHA256="84098912789dc450e95697c4184fb8a90acbe5111c2ba4aede3fecb57806a168"
BLENDER_DIR="/opt/blender-${BLENDER_VERSION}"
BLENDER_ARCHIVE="blender-${BLENDER_VERSION}-linux-x64.tar.xz"
BLENDER_URL="https://download.blender.org/release/Blender${BLENDER_SERIES}/${BLENDER_ARCHIVE}"

# Libraries Blender needs, plus a virtual desktop (Xvfb + Openbox) so the
# Blender window can run and be screenshotted (see scripts/desktop.sh).
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
	ca-certificates curl xz-utils \
	libgl1 libegl1 libglx-mesa0 libx11-6 libxi6 libxxf86vm1 libxfixes3 \
	libxrender1 libxkbcommon0 libsm6 libice6 libwayland-client0 libdbus-1-3 \
	xvfb x11-utils xdotool imagemagick openbox mesa-utils \
	>/dev/null

if [ ! -x "${BLENDER_DIR}/blender" ]; then
	tmp="$(mktemp -d)"
	trap 'rm -rf "${tmp}"' EXIT

	curl -sSLf "${BLENDER_URL}" -o "${tmp}/${BLENDER_ARCHIVE}"
	echo "${BLENDER_SHA256}  ${tmp}/${BLENDER_ARCHIVE}" | sha256sum -c --quiet -

	mkdir -p "${BLENDER_DIR}"
	tar -xJf "${tmp}/${BLENDER_ARCHIVE}" -C "${BLENDER_DIR}" --strip-components=1
fi

ln -sf "${BLENDER_DIR}/blender" /usr/local/bin/blender

blender --version | head -1

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
