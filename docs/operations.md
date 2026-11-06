# Optional host operations

Run these scripts from the host. They require Bash, Python 3, and `flock` (provided by util-linux on Linux). The Compose stack leaves scheduling up to you.

## Sync a Git inbox

Use a dedicated checkout on the `inbox` branch. Set up the `origin` remote, the local Git commit identity, and host credentials for noninteractive pushes. Review `git status --short` and the ignore rules before the first run. The script stages all tracked changes and unignored new files in the checkout.

```sh
./scripts/git-inbox-sync.sh /path/to/checkout /path/to/sync-state
```

The state directory must be outside the checkout. Use the same state directory for each invocation on a given checkout. The script saves new changes in a local commit and pushes only `origin/inbox` without forcing. If the remote has commits missing locally, the script preserves the local commit, writes `last-error`, and exits with status 3 for manual integration. The next successful sync updates `last-success` and clears `last-error`.

Run the disposable Git integration test with `python3 tests/test_git_inbox_sync.py`.

## Back up Hermes data

Install the Docker Compose plugin, `age`, `tar`, and `sha256sum`. Prepare a public age recipient file and an existing backup directory outside the data directory.

```sh
./scripts/backup.sh /path/to/hermes-workspace /path/to/age-recipients.txt /path/to/backups
```

Pass the project directory containing the running stack's `compose.yml`. Use the same Compose project name and environment as the running stack, including `COMPOSE_PROJECT_NAME` if you set it. Close any separate CLI sessions and stop other processes writing to the data directory. The script pauses the running `hermes` service by stopping it, archives the host directory mounted at `/opt/data`, and starts the service again. Back up a separate bind-mounted workspace independently.

The destination receives an encrypted archive and its SHA-256 checksum. From the backup directory, verify the checksum and inspect the archive using your private age identity.

```sh
sha256sum -c hermes-EXAMPLE.tar.gz.age.sha256
age -d -i /path/to/age-identity.txt hermes-EXAMPLE.tar.gz.age | tar -tzf -
```
