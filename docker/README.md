# Run the office in Docker on your own computer

Everything for this lives in `docker/`, so the rest of the checkout stays exactly as upstream has it and `git pull upstream main` never conflicts with it. You need Docker Desktop (Windows, macOS) or Docker Engine with the compose plugin (Linux). Nothing else: Node, Claude Code, git and the GitHub CLI are in the container.

## Start it

From the repository root:

```bash
cp docker/.env.example docker/.env
```

Set `AGENT_OFFICE_PASSWORD` in `docker/.env`, then build and start the office:

```bash
docker compose -f docker/compose.yaml up -d --build
```

The first build takes a few minutes, and the first start installs Claude Code onto the volume (it keeps updating itself there). Then open **http://localhost:4600** and sign in with the password. Without a password in `docker/.env`, the office makes one up and prints it once:

```bash
docker compose -f docker/compose.yaml logs office
```

**Claude** signs in from the office: the first worker asks you to type `/login` in its terminal, or set `ANTHROPIC_API_KEY` in `docker/.env`. **GitHub** signs in with `gh auth login` from a shell at any desk (**B**), or set `GH_TOKEN` in `docker/.env`, which also lets workers `git push`. Set `GIT_AUTHOR_NAME` and friends there for who workers commit as. Both sign-ins are kept on the volume.

## Day to day

| What | Command |
| --- | --- |
| Stop it | `docker compose -f docker/compose.yaml stop` |
| Start it again | `docker compose -f docker/compose.yaml start` |
| Follow the log | `docker compose -f docker/compose.yaml logs -f office` |
| A shell in it, as the office's user | `docker compose -f docker/compose.yaml exec -u node -e HOME=/data/home office bash` |
| Update after pulling upstream | `docker compose -f docker/compose.yaml up -d --build` |
| Remove it, keeping its data | `docker compose -f docker/compose.yaml down` |
| Remove it and everything in it | `docker compose -f docker/compose.yaml down -v` |

`restart: unless-stopped` brings the office back after a crash or when Docker starts, until you stop it. Upgrade it by pulling and rebuilding, not with **⬆️ Upgrade the office** in the **☰** menu: the code lives in the image, so the next rebuild would undo that.

## Where things are kept

Everything that has to outlive a rebuild is on the `agent-office_office-data` volume, mounted on `/data` in the container. The office's user (`node`) has its home at `/data/home`:

- `~/agent-office`: the office's data (password, accounts, floors, chat, each account's sign-ins)
- `~/workspace/<owner>/<repo>`: the projects you add from the elevator
- `~/.local`, `~/.claude`, `~/.claude.json`: Claude Code and its sign-in
- `~/.config/gh`, `~/.gitconfig`: the GitHub CLI's sign-in and git's settings

The projects are on the volume rather than in a folder on your computer because a bind mount is much slower for npm and git on Windows and macOS. To have them on your computer anyway, uncomment the bind mount in [`compose.yaml`](compose.yaml).

## Settings

Anything set in `docker/.env` reaches the office: [`.env.example`](.env.example) lists the useful ones, and every `AGENT_OFFICE_*` setting in [docs/configuration.md](../docs/configuration.md) works. Options that only exist as flags go in `command:` in `compose.yaml`, such as `["--agent-args", "--model opus"]`. `OFFICE_HOST_PORT` moves the office off port 4600 on your computer.

**Only this computer.** The port is published on `127.0.0.1`, so nobody else on your network can reach it, and `localhost` counts as a secure origin, so voice and screen sharing work over plain http. To let your network in, drop the `127.0.0.1:` from `ports:` in `compose.yaml`. Teammates then need https for voice: add `"--self-signed"` to `command:`, or put the office behind a proxy as in [docs/self-hosting.md](../docs/self-hosting.md).

**Workers' web servers.** A dev server a worker starts listens inside the container. It shows up on the **🌐 Services** board, and `agent-office tunnel http://localhost:4600` on your computer opens each one on the same port here ([docs/tunnel.md](../docs/tunnel.md)). That needs Node on your computer: run `npm install` once in this checkout, then `npm start -- tunnel http://localhost:4600`.

## How it differs from `deploy/container/`

[`deploy/container/Dockerfile`](../deploy/container/Dockerfile) is upstream's image for hosted offices (Railway, Fly.io, Dokploy, Coolify): the office listens on `127.0.0.1` inside it and the only way in is SSH. This one has no sshd: the office listens on `0.0.0.0:4600` inside the container and compose publishes that on your computer's `localhost`. Both build from the same checkout and keep their data on a volume at `/data`.
