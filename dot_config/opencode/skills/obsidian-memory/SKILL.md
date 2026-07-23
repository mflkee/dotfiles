---
name: obsidian-memory
description: |
  Use when working with Obsidian vault: reading/writing notes, searching, 
  creating session logs, updating projects/tasks, managing memory.
  Triggers on: obsidian, vault, notes, session, project, tasks, memory, context.
---

# Obsidian Memory Skill

## Token-efficient workflow

### Session start (MANDATORY)

1. Read `opencode-memory/context-cache.md` (~500 tokens, NOT index.md!)
2. If working on specific project → read `projects/<name>.md` section only
3. Use `vault_read` with `targetType` to read specific sections

### During work

- **Search first**: `obsidian-api_search_simple(query="...")` before creating
- **Patch, don't rewrite**: `obsidian-api_vault_patch(...)` for section updates
- **Use wiki links**: `[[projects/dsync]]` instead of duplicating text
- **Read sections**: `targetType="heading"` with `target="Parent::Section"`

### Session end (MANDATORY)

1. Update `projects/<name>.md` via `vault_patch`
2. Create session log in `opencode-memory/sessions/YYYY-MM-DD-<project>.md`
3. Update `tasks/_index.md` — move completed to Done
4. **Update context-cache.md** (see Auto-cache section)

## Auto-cache mechanism

**What is it?**
`context-cache.md` is a small (~500 tokens) summary file that replaces reading the full index.md (~3000 tokens). It contains only the essential context needed to start a session.

**How does it work?**
- At session end, update this file with current state
- At session start, read this file instead of index.md
- File is auto-maintained by opencode during session lifecycle

**Trigger:** The skill description triggers on session start keywords (obsidian, vault, notes, etc.). When triggered, always read context-cache.md first.

**Template:**
```markdown
---
tags: [opencode, cache]
updated: YYYY-MM-DD
---

# Context Cache (AUTO-UPDATED)

## Current tasks
- [ ] Task description

## Active projects
- **project-name**: 1-2 sentence summary

## Recent sessions (last 5)
- YYYY-MM-DD: project — what was done
```

## MCP tools reference

- `obsidian-api_vault_read(path, targetType, target)` — read section
- `obsidian-api_vault_patch(path, targetType, target, operation, content)` — update section  
- `obsidian-api_vault_write(path, content)` — create/overwrite
- `obsidian-api_search_simple(query)` — search by content
- `obsidian-api_vault_list(path)` — list directory
- `obsidian-api_vault_get_document_map(path)` — get headings/blocks

## Token budget

| Operation | Tokens |
|-----------|--------|
| Session start (context-cache) | ~500 |
| Project section read | ~200 |
| Search query | ~100-200 |
| Section patch | ~200-300 |
| **Total per session** | **~1500-2000** |

vs current: ~6000 tokens per session.
