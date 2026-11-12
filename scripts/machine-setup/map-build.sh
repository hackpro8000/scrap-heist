#!/usr/bin/env bash
# Prepares a machine for map building: everything scripts/standby-agent.py
# and scripts/build-model.sh need on a plain Ubuntu 24.04 machine with this
# repo checked out, as the standby workflow's steps prepare a GitHub machine.
# It starts nothing and needs no secrets. Safe to run again: whatever is
# already there is left alone.
#
#   scripts/machine-setup/map-build.sh
#
# One script per purpose lives in this folder. A Claude cloud environment
# for that purpose runs it from its setup script, so every session there
# starts prepared:
#
#   if [ -d scrap-heist ]; then scrap-heist/scripts/machine-setup/map-build.sh || echo "map-build setup failed"; fi
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"

# A cloud session machine runs as root; a GitHub runner has passwordless sudo.
if [ "$(id -u)" = "0" ]; then
	as_root=()
elif sudo -n true 2> /dev/null; then
	as_root=(sudo -n)
else
	as_root=(false)
fi

# System packages the GitHub image has: git, curl, pip, a C linker for cargo.
packages=()
command -v git > /dev/null || packages+=(git)
command -v curl > /dev/null || packages+=(curl ca-certificates)
command -v python3 > /dev/null || packages+=(python3)
python3 -m pip --version > /dev/null 2>&1 || packages+=(python3-pip)
command -v cc > /dev/null || packages+=(build-essential)
if [ ${#packages[@]} -gt 0 ]; then
	echo "map-build setup: installing ${packages[*]}"
	# env inside sudo, which would otherwise drop DEBIAN_FRONTEND.
	"${as_root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get update -qq || { echo "map-build setup: need root or passwordless sudo to install ${packages[*]}" >&2; exit 1; }
	"${as_root[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${packages[@]}"
fi

# rg, sd and jq (pinned releases in ~/.local/bin).
scripts/ensure-tools.sh
export PATH="$HOME/.local/bin:$PATH"

# Rust, for when the engine has to be compiled here (scripts/build-model.sh
# takes a shared one from the build-engine branch first).
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
if ! command -v cargo > /dev/null; then
	echo "map-build setup: installing Rust"
	curl -fsSL --retry 3 https://sh.rustup.rs | sh -s -- -y -q --profile minimal
	. "$HOME/.cargo/env"
fi

# The agent's websocket library: 10.4 as the workflow installs, or 13.1
# where pip has no ready-made 10.4 for this Python (3.13 on a cloud session
# machine; building 10.4 from source fails there). Both have the same API
# for what the agent and coordinator use.
websockets_ready() {
	case "$(python3 -c 'import websockets; print(websockets.__version__)' 2> /dev/null)" in 10.4|13.1) return 0 ;; esac
	return 1
}
install_websockets() {
	python3 -m pip install --user --break-system-packages --quiet --only-binary :all: "websockets==$1" 2> /dev/null
}
websockets_ready || install_websockets 10.4 || install_websockets 13.1 || true
websockets_ready || { echo "map-build setup: no websockets 10.4 or 13.1 could be installed for $(python3 --version)" >&2; exit 1; }

echo "map-build setup: ready"
