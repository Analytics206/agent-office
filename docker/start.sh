#!/usr/bin/env bash
# Starts the office in its local container (docker/Dockerfile) as node on 0.0.0.0:4600. Arguments
# are passed on to agent-office (compose's `command:`), e.g. --budget 20 or --max-workers 4.
#
# Everything that has to outlive a restart or a rebuild lives on the volume at /data:
#   /data/home   node's home: the office's data in ~/agent-office (password, accounts, floors, chat,
#                per-account sign-ins), the projects in ~/workspace, Claude Code and its sign-in
#                (~/.local, ~/.claude, ~/.claude.json), the GitHub CLI's (~/.config/gh), ~/.gitconfig
set -euo pipefail
DATA=/data
RUN_USER=node
RUN_HOME=$DATA/home
WORKSPACE=$RUN_HOME/workspace
RUN_PATH=$RUN_HOME/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

AS_USER=(setpriv --reuid=$RUN_USER --regid=$RUN_USER --init-groups
  env HOME=$RUN_HOME USER=$RUN_USER LOGNAME=$RUN_USER SHELL=/bin/bash PATH="$RUN_PATH")

say() { echo "agent-office-docker: $*"; }

mountpoint -q $DATA || say "nothing is mounted on $DATA: the office forgets everything when this container goes"
install -d -m 755 $DATA
install -d -m 755 -o $RUN_USER -g $RUN_USER $RUN_HOME
for f in .bashrc .profile; do
  [[ -e $RUN_HOME/$f ]] || install -m 644 -o $RUN_USER -g $RUN_USER /etc/skel/$f $RUN_HOME/$f
done
cd $RUN_HOME

# Onto the volume rather than into the image, so it keeps updating itself.
if [[ ! -x $RUN_HOME/.local/bin/claude ]]; then
  say "installing Claude Code in $RUN_HOME/.local (first start)"
  "${AS_USER[@]}" bash -c 'curl -fsSL https://claude.ai/install.sh | bash' >/dev/null ||
    say "couldn't install Claude Code; it's tried again at the next start"
fi
"${AS_USER[@]}" mkdir -p "$WORKSPACE"

# A GitHub token in the environment signs gh in by itself; this lets git push with it too.
if [[ -n "${GH_TOKEN:-}${GITHUB_TOKEN:-}" ]]; then
  "${AS_USER[@]}" gh auth setup-git >/dev/null 2>&1 || say "couldn't set git up to use the GitHub token"
fi

# Once: after that, the folder is the admins' to move in ⚙️ Settings.
if [[ ! -f $RUN_HOME/agent-office/.agent-office/projects-folder.json ]]; then
  "${AS_USER[@]}" node /opt/agent-office/bin/agent-office.js setup --projects "$WORKSPACE" </dev/null
fi

# Claude Code's first-run questions (theme, trusting the workspace, an API key) would stop every
# worker's terminal, as deploy/provision.sh skips them on a server.
"${AS_USER[@]}" node - "$WORKSPACE" <<'NODE'
const fs = require('fs');
const file = `${process.env.HOME}/.claude.json`;
let c = {};
try { c = JSON.parse(fs.readFileSync(file, 'utf8')); } catch {}
c.hasCompletedOnboarding = true;
c.projects = c.projects || {};
for (const dir of process.argv.slice(2)) c.projects[dir] = { ...(c.projects[dir] || {}), hasTrustDialogAccepted: true };
const key = process.env.ANTHROPIC_API_KEY;
if (key) {
  c.customApiKeyResponses = c.customApiKeyResponses || { approved: [], rejected: [] };
  if (!c.customApiKeyResponses.approved.includes(key.slice(-20))) c.customApiKeyResponses.approved.push(key.slice(-20));
}
fs.writeFileSync(file, JSON.stringify(c, null, 2), { mode: 0o600 });
NODE

[[ -n "${AGENT_OFFICE_PASSWORD:-}" ]] ||
  say "no AGENT_OFFICE_PASSWORD set: the office makes one up and prints it below, once"
exec "${AS_USER[@]}" node /opt/agent-office/bin/agent-office.js --host 0.0.0.0 --port 4600 --no-open "$@"
