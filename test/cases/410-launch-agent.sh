#!/usr/bin/env bash
# the LaunchAgent starts the agent while the barrel is there, and removes
# itself once it is gone
#
# Its guard was written into a heredoc that the installer expands, so
# "$1" became the installer's own first argument (--manual-inventory):
# the guard found no agent, deleted the plist and unloaded itself, and no
# Mac installed that way had an agent. The plist is written here exactly
# as install.sh writes it, with an argument, and then run.

home=$WORK/home-agent
barrel=$home/.barrel
mkdir -p "$barrel/agent/bin" "$home/Library/LaunchAgents"
cat >"$barrel/agent/bin/bier-agent" <<'EOF'
#!/bin/sh
printf 'agent %s\n' "$*" >>"$HOME/agent-ran"
EOF
chmod +x "$barrel/agent/bin/bier-agent"

plist=$home/Library/LaunchAgents/com.bier.agent.plist
awk '/^cat >"\$AGENT_PLIST\.new" <<EOF$/ { on = 1; next } on && /^EOF$/ { exit } on' \
	"$REPO/install.sh" >"$WORK/plist-template"
[ -s "$WORK/plist-template" ] || fail "the plist template has to be found in install.sh"
(
	set -- --manual-inventory
	xml_barrel=$barrel xml_data=$barrel/data xml_host=test
	eval "cat <<EOF
$(cat "$WORK/plist-template")
EOF"
) >"$plist"
assert_ok plutil -lint "$plist"

script=$(/usr/bin/plutil -extract ProgramArguments.2 raw -o - "$plist")
assert_contains "$script" 'if [ -x "$1" ]; then exec "$@"; fi' \
	"the guard has to reach launch time unexpanded"

# Run it the way launchd does.
launch() {
	local args=() i=0 value
	while value=$(/usr/bin/plutil -extract "ProgramArguments.$i" raw -o - "$plist" 2>/dev/null); do
		args+=("$value")
		i=$((i + 1))
	done
	HOME=$home "${args[@]}"
}

launch
assert_file_has "$home/agent-ran" "agent serve --agent test"
[ -f "$plist" ] || fail "while the barrel is there, the plist stays"

# After rm -rf ~/.barrel, it cleans up after itself.
rm -rf "$barrel"
launch
[ ! -e "$plist" ] || fail "without the barrel, the plist has to go"
assert_file_has "$WORK/launchctl.args" "bootout gui/"
