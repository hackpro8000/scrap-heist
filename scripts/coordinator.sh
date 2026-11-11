#!/usr/bin/env bash
# Starts, stops or reports the build coordinator (tools/coordinator/) in
# this session, with an address the standby machines can reach.
#
#   scripts/coordinator.sh start [tailscale|cloudflare|auto] [--dry-upload]
#   scripts/coordinator.sh url        # the address to give standby machines
#   scripts/coordinator.sh status
#   scripts/coordinator.sh machines   # what each machine is doing right now
#   scripts/coordinator.sh stop
#   scripts/coordinator.sh attach [run id]   # use machine 1's coordinator
#   scripts/coordinator.sh key        # prints this session's control key
#
# attach points this session at the coordinator build machine 1 runs for
# that standby run: through its Cloudflare tunnel when the run published
# one (address.json on build-results/coordinator-address; the newest run
# when no id is given), else over the tailnet. stop then ends its machines
# but kills nothing here. key makes, once, the key pair whose signature
# machine 1's control port asks for; only the public half leaves here.
#
# Routes: tailscale puts the machine port on this session's tailnet address
# (the machines join the tailnet with the repo's TS_AUTHKEY secret);
# cloudflare keeps it on localhost and opens a Cloudflare quick tunnel to it,
# an https address made by an outbound connection only. auto takes tailscale
# when this session is on a tailnet and the repo has TS_AUTHKEY, else
# cloudflare. Either way a machine is let in only with GitHub's identity
# token for this repo's standby workflow (tools/coordinator/oidc.py).
#
# Uploads run here when this session has the Roblox key (ROBLOX_API_KEY, or
# ~/.config/scrap-heist/roblox-api-key); without it, build machine 1 does
# them with the repo's ROBLOX_API_KEY secret, still over the live
# connections. If this session can't connect out at all, start standby with
# scripts/standby-start.sh --on-machine.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
state="${HOME}/.cache/scrap-heist/coordinator.json"
logs="${HOME}/.cache/scrap-heist"
agent_port=8765
mkdir -p "${logs}"

json() {
	python3 -c "import json,sys; print(json.load(open('${state}')).get('$1', ''))" 2> /dev/null || true
}

remote() {
	[ -f "${state}" ] && [ "$(json remote)" = True ]
}

running() {
	remote || { [ -f "${state}" ] && kill -0 "$(json pid)" 2> /dev/null; }
}

attach() {
	local address
	if running; then
		echo "a coordinator is already running here; scripts/coordinator.sh stop it first" >&2
		return 1
	fi
	address="$(gh api -H "Accept: application/vnd.github.raw" \
		"repos/{owner}/{repo}/contents/address.json?ref=build-results/coordinator-address" 2> /dev/null || true)"
	python3 - "${state}" "${1:-}" "${address}" << 'PY'
import json, sys
path, run, address = sys.argv[1:]
try:
	address = json.loads(address)
except ValueError:
	address = {}
if address.get("control") and (not run or str(address.get("run")) == run):
	run = str(address["run"])
	state = {"remote": True, "control": address["control"], "agent_url": address["agent"], "route": "machine-1 over cloudflare"}
elif run:
	state = {"remote": True, "control": f"ws://scrap-coordinator-{run}:8766", "agent_url": "machine-1", "route": "machine-1 over tailscale"}
else:
	sys.exit("no address published by machine 1 yet; give the run id to attach over the tailnet")
json.dump(state, open(path, "w"))
print(f"attached to machine 1's coordinator of run {run} ({state['route']})", file=sys.stderr)
PY
}

key() {
	local key="${logs}/control-key"
	if [ ! -f "${key}" ]; then
		ssh-keygen -q -t ed25519 -N "" -C scrap-heist-control -f "${key}" < /dev/null
		echo "made ${key}; it never leaves this computer" >&2
	fi
	cat "${key}.pub"
}

set_url() {
	python3 - "${state}" "$1" "$2" << 'PY'
import json, sys
path, url, route = sys.argv[1:]
state = json.load(open(path))
state["agent_url"], state["route"] = url, route
json.dump(state, open(path, "w"))
PY
}

route_for() {
	local wanted="$1"
	if [ "${wanted}" != "auto" ]; then
		echo "${wanted}"
	elif tailscale ip -4 > /dev/null 2>&1 && gh secret list 2> /dev/null | grep -q "^TS_AUTHKEY"; then
		echo tailscale
	elif command -v cloudflared > /dev/null; then
		echo cloudflare
	else
		echo none
	fi
}

start() {
	local route dry="" host="127.0.0.1" url
	route="$(route_for "${1:-auto}")"
	[ "${2:-}" = "--dry-upload" ] && dry="--dry-upload"
	if [ -z "${dry}" ] && [ -z "${ROBLOX_API_KEY:-}" ] && [ ! -f "${HOME}/.config/scrap-heist/roblox-api-key" ]; then
		dry="--uploads-on-machine"
		echo "no Roblox key in this session: build machine 1 will upload with the repo's secret" >&2
	fi
	if running; then
		echo "coordinator already running: $(json agent_url)" >&2
		return 0
	fi
	case "${route}" in
		tailscale) host="$(tailscale ip -4 | head -n 1)" ;;
		cloudflare) ;;
		*) echo "no route out of this session: start standby without a coordinator" >&2; return 1 ;;
	esac
	cd "${root}"
	nohup setsid python3 tools/coordinator/coordinator.py serve --agent-host "${host}" --agent-port "${agent_port}" ${dry} \
		> "${logs}/coordinator.log" 2>&1 < /dev/null &
	for _ in $(seq 1 50); do
		grep -q "machines on" "${logs}/coordinator.log" 2> /dev/null && break
		sleep 0.2
	done
	running || { echo "coordinator did not start:" >&2; tail -n 20 "${logs}/coordinator.log" >&2; return 1; }
	if [ "${route}" = tailscale ]; then
		url="ws://${host}:${agent_port}"
	else
		nohup setsid cloudflared tunnel --no-autoupdate --url "http://127.0.0.1:${agent_port}" \
			> "${logs}/tunnel.log" 2>&1 < /dev/null &
		echo $! > "${logs}/tunnel.pid"
		url=""
		for _ in $(seq 1 100); do
			url="$(grep -o 'https://[a-z0-9-]*\.trycloudflare\.com' "${logs}/tunnel.log" | head -n 1 || true)"
			[ -n "${url}" ] && break
			sleep 0.3
		done
		[ -n "${url}" ] || { echo "the Cloudflare tunnel did not come up:" >&2; tail -n 20 "${logs}/tunnel.log" >&2; stop; return 1; }
		url="wss://${url#https://}"
	fi
	set_url "${url}" "${route}"
	echo "coordinator up over ${route}: ${url}" >&2
}

stop() {
	# Machines first: left running they'd hold all the account's machine
	# slots, and a new standby run would wait in GitHub's queue behind them.
	if running; then
		python3 "${root}/tools/coordinator/client.py" stop-machines > /dev/null 2>&1 && echo "told the machines to stop" >&2 || true
	fi
	# Machine 1 runs a remote coordinator: nothing here to kill.
	if remote; then
		rm -f "${state}"
		echo "detached from machine 1's coordinator" >&2
		return 0
	fi
	if [ -f "${logs}/tunnel.pid" ]; then
		kill "$(cat "${logs}/tunnel.pid")" 2> /dev/null || true
		rm -f "${logs}/tunnel.pid"
	fi
	if running; then
		kill "$(json pid)" 2> /dev/null || true
	fi
	rm -f "${state}"
	echo "coordinator stopped" >&2
}

case "${1:-status}" in
	start) start "${2:-auto}" "${3:-}" ;;
	stop) stop ;;
	attach) attach "${2:-}" ;;
	key) key ;;
	url) running && json agent_url ;;
	status)
		if running; then
			echo "coordinator up over $(json route): $(json agent_url)"
			python3 "${root}/tools/coordinator/client.py" status || true
		else
			echo "no coordinator running"
		fi
		;;
	machines) python3 "${root}/tools/coordinator/client.py" machines ;;
	*) sed -n '2,25p' "$0" >&2; exit 1 ;;
esac
