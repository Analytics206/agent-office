# Agent Office in a local Docker container: `docker compose -f docker/compose.yaml up -d --build`
# from the repository root (see docker/README.md).
#
# Unlike deploy/container/Dockerfile (the hosted image, reached only through SSH), this one is for
# running the office on your own computer: the office listens on 0.0.0.0:4600 inside the container
# and compose publishes it on 127.0.0.1:4600, so http://localhost:4600 counts as a secure origin and
# voice and screen sharing work. Everything that has to outlive a rebuild lives on the /data volume.
#
# Everything for Docker lives in docker/, so the rest of the checkout stays as upstream has it.
FROM node:22-bookworm-slim AS build
WORKDIR /opt/agent-office
COPY package.json package-lock.json ./
# No install scripts: `prepare` would build before the sources are here.
RUN npm ci --ignore-scripts --no-audit --no-fund
COPY . .
RUN chmod 755 bin/*.js \
  && npm run build && npm prune --omit=dev --ignore-scripts --no-audit --no-fund

FROM node:22-bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8
# tini to reap what workers leave behind, `ss` (iproute2) for the office to find the web servers
# workers start, and what workers need: git, ssh, the GitHub CLI (from GitHub's own apt repo) and
# build tools.
RUN apt-get update \
  && apt-get install -y --no-install-recommends tini procps iproute2 ca-certificates curl git less openssh-client build-essential python3 \
  && install -d -m 755 /etc/apt/keyrings \
  && curl -fsSLo /etc/apt/keyrings/githubcli-archive-keyring.gpg https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    >/etc/apt/sources.list.d/github-cli.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends gh \
  && rm -rf /var/lib/apt/lists/*
COPY --from=build /opt/agent-office /opt/agent-office
COPY docker/start.sh /usr/local/bin/agent-office-docker
# The office runs as node (uid 1000) with its home on the volume. A Windows checkout may have given
# the script CRLF line endings, which bash can't run.
RUN sed -i 's/\r$//' /usr/local/bin/agent-office-docker \
  && chmod 755 /usr/local/bin/agent-office-docker \
  && usermod --home /data/home --shell /bin/bash node \
  && rm -rf /home/node
VOLUME /data
EXPOSE 4600
HEALTHCHECK --interval=30s --timeout=5s --start-period=120s \
  CMD curl -fs http://127.0.0.1:4600/api/health || exit 1
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/agent-office-docker"]
