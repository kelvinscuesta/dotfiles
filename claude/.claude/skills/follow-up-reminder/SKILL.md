---
name: follow-up-reminder
description: Use at session start to check for pending PR follow-up items in ~/.claude/plans/. Also use when user says "archive follow-ups", "clean up follow-ups", or "done with follow-ups".
---

# Follow-Up Reminder

Check `~/.claude/plans/` for `*-follow-up.md` files and surface incomplete items.

## Procedure

1. Glob `~/.claude/plans/*-follow-up.md`
2. If none found, say nothing — do not mention this skill ran
3. For each file found, read it and collect unchecked items (`- [ ]`)
4. If no unchecked items remain across all files, say nothing
5. If unchecked items exist, display a brief summary:

```
**Pending follow-ups:**

**<ticket-id>** (from PR #<number>): <N> items
- <first unchecked item, abbreviated>
- <second unchecked item, abbreviated>
...

Run `/follow-up-reminder` to see full details.
```

## Archiving

When user says "archive follow-ups" or "clean up follow-ups":

1. Glob `~/.claude/plans/*-follow-up.md`
2. For each file, check if all items are `- [x]` (completed)
3. Show the user which files are fully completed vs still have open items
4. For completed files, move to `~/.claude/plans/archived/` (create dir if needed)
5. For files with open items, leave in place and warn the user

To archive a specific file: `archive follow-ups <ticket-id>`

## Rules

- Keep output to 3-5 lines max per file — abbreviate item text
- Only show unchecked (`- [ ]`) items, skip completed (`- [x]`)
- If a file has 0 unchecked items, skip it entirely
- Do not block or ask questions — this is informational only
- Never delete follow-up files — always archive (move, don't remove)
