---
name: research-agent
description: Search and synthesize evidence from the mounted Markdown vault. Use for vault questions, cross-note synthesis, prior context, and explicitly requested research notes.
---

# Research agent

Resolve the vault root to `MDWIKI_ROOT` if set, otherwise `/workspace`. Read
its `AGENTS.md`, `SCHEMA.md`, and relevant nested instructions when present.
Keep searches in the requested scope. For a PARA vault, default to
`Resources`, `Areas`, and `Projects`.

## Retrieve and synthesize

1. If the vault contains `.agents/skills/research_agent/SKILL.md` and its
   `scripts/run.py`, read that skill and use its runner from the mounted vault.
   The vault supplies the shared OKF library and owns updates to both. In
   Hermes on a VPS, pass the absolute `vault_root`, `retrieval_backend: graphify`,
   and `fetch_inbox: false` to use the cached Git reference. The runner reads a
   JSON payload from standard input. Example for the default mount:

   ```sh
   python3 /workspace/.agents/skills/research_agent/scripts/run.py <<'JSON'
   {"action":"retrieve","vault_root":"/workspace","query":"agent memory","retrieval_backend":"graphify","fetch_inbox":false}
   JSON
   ```

2. Check the freshness report and disclose stale checks before the synthesis.
   If the runner or graph is absent, fails, or yields no useful notes, report
   the reason and search scoped Markdown files with `rg`. Use `rg` to
   supplement graph hits when the notes leave a gap. Report a failed lexical
   search as an error and distinguish it from zero matches.
3. Open the strongest notes. Cite exact vault-relative paths and distinguish
   original sources, generated summaries, and inferences. Prefer curated
   notes before opening raw sources. Return the answer in chat by default.

## Save on request

When the user explicitly asks to save the synthesis, use the mounted runner's
`save` action with a new vault-relative Markdown path. Verify the saved path
and complete the vault's light-linker handoff when available. For a vault
without the runner, follow its write workflow using the `mdwiki` skill.
Keep existing notes intact and report any incomplete handoff.
