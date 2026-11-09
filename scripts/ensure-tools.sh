#!/usr/bin/env bash
# Puts the command-line tools this repository's rules and hooks rely on (rg,
# sd, jq) on this machine, in ~/.local/bin. Safe to run at any time: a tool
# already on the machine is left alone, so a repeat run takes milliseconds.
#
# Every release is pinned and checked against its SHA-256. Runs from the
# SessionStart hook in .claude/settings.json and from scripts/standby-agent.py,
# and adds the folder to PATH for what runs next.
#
#   scripts/ensure-tools.sh
set -euo pipefail

BIN="$HOME/.local/bin"

download() { # repo tag asset destination
	local url="https://github.com/$1/releases/download/$2/$3"
	curl -fsSL --retry 3 --retry-delay 2 -o "$4" "$url" 2>/dev/null && return 0
	# github.com's plain download links sometimes answer 504 for one asset
	# while the API serves it fine.
	command -v gh >/dev/null && gh release download "$2" -R "$1" -p "$3" -O "$4" --clobber 2>/dev/null
}

install_tool() { # name repo tag asset sha256 file-in-archive (empty: the asset is the binary)
	local name="$1" repo="$2" tag="$3" asset="$4" sha="$5" member="$6"
	PATH="$BIN:$PATH" command -v "$name" >/dev/null && return 0
	local work
	work="$(mktemp -d)"
	trap 'rm -rf "$work"' RETURN
	if ! download "$repo" "$tag" "$asset" "$work/asset"; then
		echo "ensure-tools: could not download $name $tag" >&2
		return 1
	fi
	if ! echo "$sha  $work/asset" | sha256sum --check --status; then
		echo "ensure-tools: $name $tag does not match its pinned checksum" >&2
		return 1
	fi
	local binary="$work/asset"
	if [ -n "$member" ]; then
		tar -xzf "$work/asset" -C "$work" "$member"
		binary="$work/$member"
	fi
	mkdir -p "$BIN"
	# Atomic, for two sessions starting at once.
	install -m 755 "$binary" "$BIN/.$name.$$"
	mv -f "$BIN/.$name.$$" "$BIN/$name"
	echo "ensure-tools: installed $name $tag"
}

if [ "$(uname -s)-$(uname -m)" != "Linux-x86_64" ]; then
	echo "ensure-tools: only Linux x86_64 releases are pinned; install rg, sd and jq by hand on $(uname -s)-$(uname -m)" >&2
	exit 1
fi

missing=0
install_tool rg BurntSushi/ripgrep 14.1.1 ripgrep-14.1.1-x86_64-unknown-linux-musl.tar.gz \
	4cf9f2741e6c465ffdb7c26f38056a59e2a2544b51f7cc128ef28337eeae4d8e \
	ripgrep-14.1.1-x86_64-unknown-linux-musl/rg || missing=1
install_tool sd chmln/sd v1.0.0 sd-v1.0.0-x86_64-unknown-linux-musl.tar.gz \
	9f42e4fec7848fa8d6eeab7b1090f5c9c9e374c94a9974db6ff33df052c9e132 \
	sd-v1.0.0-x86_64-unknown-linux-musl/sd || missing=1
install_tool jq jqlang/jq jq-1.7.1 jq-linux-amd64 \
	5942c9b0934e510ee61eb3e30273f1b3fe2590df93933a93d7c58b81d19c8ff5 \
	"" || missing=1

# GitHub Actions steps and Claude Code sessions each have their own way of
# carrying PATH to whatever runs next.
[ -n "${GITHUB_PATH:-}" ] && echo "$BIN" >> "$GITHUB_PATH"
[ -n "${CLAUDE_ENV_FILE:-}" ] && echo "export PATH=\"$BIN:\$PATH\"" >> "$CLAUDE_ENV_FILE"
exit "$missing"
