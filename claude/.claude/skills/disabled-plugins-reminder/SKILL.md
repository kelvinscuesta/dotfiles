---
name: disabled-plugins-reminder
description: Use at the start of any conversation when the user's task might benefit from a disabled plugin like Atlassian (Jira/Confluence), Playwright (browser testing), or Slack (messaging/search).
---

# Disabled Plugins Reminder

## Overview

Some plugins are disabled to save context window. Remind the user when their task would benefit from re-enabling one.

## Disabled Plugins

| Plugin | Re-enable command | Use case |
|--------|-------------------|----------|
| `atlassian` | `/plugin install atlassian@claude-plugins-official` | Jira issues, Confluence pages, search |
| `playwright` | `/plugin install playwright@claude-plugins-official` | Browser automation, visual testing, screenshots |
| `slack` | `/plugin install slack@claude-plugins-official` | Search messages, channel history, standups |

## When to Remind

If the user's task involves any of these, mention the relevant plugin:
- Jira tickets, Confluence → atlassian
- Browser testing, UI verification, screenshots → playwright
- Slack messages, channel activity, standups → slack

**Format:** Keep it brief. One line, e.g.: "This would benefit from the atlassian plugin. Re-enable with `/plugin install atlassian@claude-plugins-official` and restart the session."

**Don't remind** if the task has no connection to these tools.
