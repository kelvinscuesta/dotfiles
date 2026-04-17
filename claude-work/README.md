# claude-work

Claude Code work-scope configuration: workflow automation server, skills, hooks, permissions.

Stowed into `~/.claude/`. Pair with the separate `skhd` package for keyboard shortcuts.

## Layout

```
.claude/
├── settings.json              # work-scope permissions, hooks, env
├── hooks/
│   └── workflow-preamble.sh   # SessionStart hook — injects context into headless runs
├── skills/
│   ├── wf-*                   # workflow skills (start/stop/feed/approve/classify/implement/analyze-pr/...)
│   └── workflow-pr            # PR creation (repo template discovery + draft PR)
├── workflow/
│   ├── scripts/               # poll-jira, poll-prs, audit, update-dashboard, notify-slack
│   └── templates/status.html  # dashboard template
└── workflow-server/           # long-running Bun/TS server
    ├── src/                   # server, runner, dashboard, reconcile, pending, state, slack-drain, stale
    ├── scripts/               # server-start/stop/status, shortcut-*, install-swiftbar, swiftbar-autostart
    ├── swiftbar/              # SwiftBar menu bar plugin
    ├── package.json
    ├── tsconfig.json
    └── .env.example           # copy to .env and fill per-user values
```

## Setup

1. **Stow package:** `stow -t ~ claude-work` (from the dotfiles root)
2. **Env:** `cp ~/.claude/workflow-server/.env.example ~/.claude/workflow-server/.env` — fill in `SLACK_CHANNEL_ID`, `JIRA_PROJECT`, `GITHUB_REPOS`, `BRANCH_PREFIX`
3. **Bun:** install Bun (`curl -fsSL https://bun.sh/install | bash`) — server runs on Bun
4. **Tool auth:**
   - `gh auth login`
   - `acli` configured against your Atlassian tenant
5. **MCP servers** (in Claude Code): enable Slack, Jira/Confluence, GitHub servers. Channel posting uses `SLACK_CHANNEL_ID` from `.env`.
6. **Boot:**
   - `/wf-start` inside Claude Code, or
   - `~/.claude/workflow-server/scripts/server-start.sh` directly
7. **SwiftBar (optional):** `~/.claude/workflow-server/scripts/install-swiftbar.sh` — menu bar status + quick actions
8. **skhd (optional):** stow the separate `skhd` package → `brew services start skhd`

## Env vs secrets

`settings.json` and skill markdown files are committed. `.env`, logs, queue state, audit history, plans, drafts, and sidecars are all runtime state in `~/.claude/workflow/` and `~/.claude/workflow-server/` — never committed.

## Work-specific placeholders

Skills reference these via `.env`:

| Placeholder              | Where                                      | Example                 |
|--------------------------|--------------------------------------------|-------------------------|
| `SLACK_CHANNEL_ID`       | thread posting in wf-classify/implement/analyze-pr/slack-drain | `C0ABCDEFGHI`           |
| `#your-automation-channel` | Slack channel name (cosmetic)             | `#my-automation`        |
| Branch prefix `kelvin/…` | wf-implement branch naming                 | change to `yourname/…`  |
| `Gusto/...` repos        | plan templates, runner cwd resolution      | your org's repos        |

Skills embed `YOUR_SLACK_CHANNEL_ID` as a literal — replace once in skills after setup, or have Claude read from `.env` at runtime.

## Keyboard shortcuts (skhd package)

Installed via `~/.config/skhd/skhdrc`:

- `ctrl+alt+w` — open dashboard
- `ctrl+alt+s` — toggle workflow server
- `ctrl+alt+l` — tail server logs in Ghostty
- `ctrl+alt+/` — print server status
