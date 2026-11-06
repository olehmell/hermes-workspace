# Hermes Workspace

A GitHub template for running [Hermes Agent](https://github.com/NousResearch/hermes-agent)
on a Linux VPS with Docker Compose. It builds on the official multi-platform
image and bundles the tools for a Markdown vault, document conversion, YouTube
captions, and optional browser automation.

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
docker compose build --pull
docker compose run --rm --no-deps hermes setup
docker compose run --rm --no-deps hermes config set terminal.cwd /workspace
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

## Telegram

Hermes v0.23.0 expands hidden Telegram links in message text and media captions.
A small patch keeps each hidden destination at its first anchor when the same
URL appears in several entities. The regression test exercises
hidden links, duplicates, captions, channel posts, Unicode offsets, and plain
text with synthetic updates. Run it after starting the service.

```sh
docker run --rm --network none -i --workdir /opt/hermes \
  --entrypoint /opt/hermes/.venv/bin/python "$(docker compose images -q hermes)" \
  - < tests/smoke_telegram_text_links.py
```

### Save Ukrainian summaries from Telegram

Point `HERMES_WORKSPACE_DIR` at your mdwiki checkout in the root Compose
`.env`. Configure a model and Telegram in the Hermes setup wizard and
restrict bot access to your Telegram user ID. Keep bot tokens, provider
credentials, and cookies in the private Hermes data directory.

Send `/ukrainian_summary https://example.com/article` in a direct chat with
your bot. To make a message containing only a URL invoke the same skill,
add `HERMES_TELEGRAM_AUTO_SUMMARY=1` to the root Compose `.env` and recreate
the Hermes service.

```sh
docker compose build hermes
docker compose up -d hermes
```

Hermes verifies the source, saves the Ukrainian Markdown summary in the
vault's intake folder, and replies with the path and the note attached.
Automatic routing applies to URL-only text in authorized direct chats.
The normal Telegram command permissions still apply.

## Use your own workspace

Hermes can read and write the contents of `workspace/`. The bundled `mdwiki`
skill searches and edits Markdown while following the vault's `AGENTS.md` and
`SCHEMA.md` when present. To use an existing checkout or vault, set
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

The bundled `research-agent` skill delegates to
`.agents/skills/research_agent/scripts/run.py` when the mounted vault contains
the mdwiki research skill. It uses Graphify and the vault's own OKF helpers.
For a plain Markdown workspace or an unavailable graph, it can search scoped
notes with `rg` and cite the matching files. It saves a synthesis only when
requested.

## Media and documents

`yt-dlp` uses the bundled Node runtime and a private PO-token provider on the
Compose network. `ffmpeg` handles media, `anydoc` converts documents, and
`graphify` builds knowledge graphs. The image also includes `rg`, `gh`,
`jq`, and PyYAML for vault workflows.

```sh
docker compose exec --user hermes --env HOME=/opt/data hermes yt-dlp --list-subs 'YOUTUBE_URL'
```

YouTube may require sign-in for a video or server IP. Treat a bot challenge or
rate limit as an access failure when determining whether captions exist.
Use the [yt-dlp authentication guide](https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp)
if you need your own cookies. Store the cookie file under the private data
directory and pass its container path to `yt-dlp --cookies`.

## Optional browser

Start the Camofox sidecar, install the plugin revision from the Hermes v0.23.0
catalog, then enable the browser tools. The plugin retries with a fresh tab
after HTTP 404 or 410. Its control API stays on the Compose network.

```sh
docker compose --profile browser up -d --wait camofox
printf '%s\n' 'http://camofox:9377' | docker compose exec -T hermes \
  hermes plugins install 'NousResearch/hermes-official-plugins#camofox' \
  --ref 1138f25c8b7b5a8fb882b3161e248f29abbd1a46 --yes-deps --enable
docker compose exec hermes hermes tools enable camofox
docker compose exec hermes hermes camofox status
```

To persist browser identities, set `browser.camofox.managed_persistence` to
`true` in the Hermes config. Profiles live in the `camofox-data` Docker volume.

## Optional host operations

The template includes scripts for [syncing a vault's Git inbox and creating
encrypted backups](docs/operations.md). Run them from the host on your own
schedule.

## Update Hermes

The base image in `Dockerfile` pins both the release and its multi-platform
digest. Back up `data/` (or your configured data directory), then change the
image reference to the desired [upstream release](https://github.com/NousResearch/hermes-agent/releases)
and matching [Docker Hub digest](https://hub.docker.com/r/nousresearch/hermes-agent/tags).
Run `docker compose build --pull` and `docker compose up -d` to recreate the
service with the same directories. Run the Telegram regression test after
changing the base image.

See the [official Hermes Docker guide](https://hermes-agent.nousresearch.com/docs/user-guide/docker)
for more on setup, messaging, and extending the upstream image.
