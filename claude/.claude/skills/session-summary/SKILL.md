---
name: session-summary
description: Use when a PR has been pushed/created, or user asks to summarize the session's work. Generates a structured summary doc of all work done.
---

# Session Summary

Generate a structured summary of all work done in the current session after pushing a PR.

## When to Use

- After pushing a PR
- When user asks to summarize work done
- At end of a development session

## Procedure

1. Gather context from the session: ticket ID, branch, commits, PR URL, files changed, key decisions
2. Write summary to `~/.claude/research/<ticket-id>-session-summary.md`
3. If no ticket ID, use `<topic>-session-summary.md`

## Template

```markdown
# <TICKET-ID> Session Summary

## Ticket
[<TICKET-ID>](<jira-url>) — <title>

## Outcome
<1-2 sentence summary of what was accomplished>

## PR
[#<number>](<github-url>) — <status>

## Branch
<branch-name>

## Commits
<numbered list with SHA + message>

## What Changed
<grouped by area: GraphQL, components, tests, etc.>

## Key Decisions
<important architectural/design decisions and rationale>

## Follow-ups
<any follow-up items created, resolved, or remaining>

## Files Modified
<bullet list of files touched>
```

## Rules

- Keep it factual, not narrative
- Group changes by area, not chronologically
- Include links (PR, ticket, feature flags) when available
- Note any follow-up items resolved from previous PRs
