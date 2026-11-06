#!/usr/bin/env python3
"""Offline integration test using disposable local Git repositories (Linux)."""
import fcntl
from pathlib import Path
import subprocess
import tempfile

script = Path(__file__).resolve().parents[1] / "scripts" / "git-inbox-sync.sh"
def cmd(*args, cwd=None, expected=0):
    p = subprocess.run(args, cwd=cwd, capture_output=True, text=True)
    if p.returncode != expected:
        raise AssertionError(f'{args[0]} exit {p.returncode}, expected {expected}: {p.stdout} {p.stderr}')
    return p.stdout.strip()

with tempfile.TemporaryDirectory(prefix='hermes-git-sync-test-') as tmp:
    root = Path(tmp)
    remote, repo, state, other = [root / x for x in ('remote.git', 'repo', 'state', 'other')]
    cmd('git', 'init', '--bare', '-q', str(remote))
    cmd('git', 'init', '-q', '-b', 'inbox', str(repo))
    for k, v in [('user.name', 'Sync test'), ('user.email', 'test@example.invalid')]:
        cmd('git', 'config', k, v, cwd=repo)
    cmd('git', 'remote', 'add', 'origin', str(remote), cwd=repo)
    (repo / '.gitignore').write_text('.env\n')
    (repo / 'README.md').write_text('base\n')
    (repo / 'delete-me.md').write_text('old\n')
    cmd('git', 'add', '-A', cwd=repo)
    cmd('git', 'commit', '-qm', 'base', cwd=repo)
    run = lambda expected=0: cmd('bash', str(script), str(repo), str(state), expected=expected)
    remote_head = lambda: cmd('git', '--git-dir', str(remote), 'rev-parse', 'refs/heads/inbox')
    run()
    assert remote_head() == cmd('git', 'rev-parse', 'HEAD', cwd=repo)
    (repo / 'README.md').write_text('edited\n')
    (repo / 'new.md').write_text('new\n')
    (repo / 'delete-me.md').unlink()
    (repo / '.env').write_text('DUMMY_TEST_SECRET=not-a-real-secret\n')
    run()
    tree = cmd('git', '--git-dir', str(remote), 'ls-tree', '-r', '--name-only', 'inbox').splitlines()
    assert 'new.md' in tree and 'delete-me.md' not in tree and '.env' not in tree
    before = remote_head()
    run()
    assert remote_head() == before
    cmd('git', 'switch', '-qc', 'another', cwd=repo)
    run(expected=2)
    assert remote_head() == before
    cmd('git', 'switch', '-q', 'inbox', cwd=repo)
    with (state / 'sync.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        (repo / 'locked.md').write_text('queued\n')
        run()
        assert remote_head() == before
        assert '?? locked.md' in cmd('git', 'status', '--short', cwd=repo)
    run()
    cmd('git', 'clone', '-q', '-b', 'inbox', str(remote), str(other))
    for k, v in [('user.name', 'Other test'), ('user.email', 'other@example.invalid')]:
        cmd('git', 'config', k, v, cwd=other)
    (other / 'remote.md').write_text('remote\n')
    cmd('git', 'add', '-A', cwd=other)
    cmd('git', 'commit', '-qm', 'remote change', cwd=other)
    cmd('git', 'push', '-q', cwd=other)
    before = remote_head()
    (repo / 'local.md').write_text('keep me\n')
    run(expected=3)
    assert remote_head() == before
    assert cmd('git', 'show', 'HEAD:local.md', cwd=repo) == 'keep me'
    assert (state / 'last-error').exists()
    print('PASS: initial push, add/edit/delete, gitignore, no-op, wrong branch, lock, divergence preserves both histories')
