# Hermes Workspace

A GitHub template for running [Hermes Agent](https://github.com/NousResearch/hermes-agent)
on a Linux VPS with Docker Compose. It pulls the official multi-platform image
and gives the agent a working directory for notes, files, or a Git checkout.

## Start on a VPS

Install Docker Engine with the Compose plugin. Select **Use this template** on
GitHub and clone the resulting repository, or clone this one directly.

```sh
git clone https://github.com/olehmell/hermes-workspace.git
cd hermes-workspace
```

Run the initial setup from the checkout as a non-root user who can run Docker.

```sh
mkdir -p -m 700 data workspace
printf 'HERMES_UID=%s\nHERMES_GID=%s\n' "$(id -u)" "$(id -g)" > .env
docker compose pull
docker compose run --rm hermes setup
docker compose run --rm hermes config set terminal.cwd /workspace
docker compose up -d
docker compose logs --tail=50 hermes
```

The setup wizard configures the model and, optionally, a messaging platform such
as Telegram. If it offers to install or start a gateway service, skip that step
so Compose can manage the gateway. Restrict messaging access to your own user
IDs in the wizard. The Compose service publishes no host ports and leaves the
dashboard off.

For CLI use inside the running container, run
`docker compose exec hermes hermes --help`.

## Use your own workspace

Hermes can read and write the contents of `workspace/`. Put your files and
project instructions there. To use an existing checkout or vault, set
`HERMES_WORKSPACE_DIR=/absolute/path/to/checkout` in the root `.env`. Only point
it at a directory you want the agent to access and that your host user can write.

Hermes stores configuration, credentials, sessions, and memory under `data/`.
You can put that state outside the checkout by setting
`HERMES_DATA_DIR=/absolute/path/to/hermes-data` in the root `.env`. Create both
directories before starting Compose. Keep the data and workspace directories
separate. If you use custom directories, keep them outside this repository so
their contents stay out of its Git history.

To load skills from your workspace, add the directory containing their
`SKILL.md` folders to `skills.external_dirs` in the Hermes `config.yaml`.
Use the path as Hermes sees it inside the container, such as
`/workspace/.agents/skills`. Restart Hermes after changing the setting.

## Update Hermes

The image reference in `compose.yml` pins both the release and its multi-platform
digest. Back up `data/` (or your configured data directory), then change the
image reference to the desired [upstream release](https://github.com/NousResearch/hermes-agent/releases)
and matching [Docker Hub digest](https://hub.docker.com/r/nousresearch/hermes-agent/tags).
Run `docker compose pull` and `docker compose up -d` to recreate the service
with the same directories.

See the [official Hermes Docker guide](https://hermes-agent.nousresearch.com/docs/user-guide/docker)
for more on setup, messaging, and extending the upstream image.
