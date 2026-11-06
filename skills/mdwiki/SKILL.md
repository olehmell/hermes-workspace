---
name: mdwiki
description: Search, read, create, and edit Markdown notes in a Git-backed mdwiki vault. Follow the vault's metadata, placement, and linking rules.
---

# mdwiki

1. Resolve the vault to `MDWIKI_ROOT` if set, otherwise `/workspace`. Use
   absolute paths for file operations. Check that the root exists and read
   its `AGENTS.md`, `SCHEMA.md`, and the applicable nested instructions when
   present. Those files define placement, metadata, and post-write workflows.
2. Use `rg --files` to find notes and `rg -n` to search text. For edits, read
   the target note first. Preserve its language, filename, unrelated YAML
   metadata, Markdown links, and `[[wikilinks]]`.
3. Write UTF-8 Markdown. Follow `SCHEMA.md` for new or changed frontmatter and
   the vault's documented intake path for summaries. If the vault uses lean
   OKF, keep YAML at the start of the file and follow the allowed fields in
   the schema. For a new note, run any linker or indexing step the vault
   requires and has configured.
4. Read the saved file back. Check that the body is nonempty and that the
   frontmatter, if present, parses. Report the saved path. Use the vault's
   documented Git workflow and report a commit or push only after verifying it.
