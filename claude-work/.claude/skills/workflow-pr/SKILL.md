---
name: workflow-pr
description: Create draft pull requests. Use when user asks to create a PR, open a PR, or submit code for review.
argument-hint: "[optional JIRA ticket ID]"
---

# PR Creation Workflow

Create well-structured, reviewable pull requests. Primary tool: GitHub CLI (gh). PRs always created as DRAFT.

## Workflow

1. Check current branch and uncommitted changes
2. Verify not on main/master, has commits to include
3. Review commits to include
4. Determine if Jira ticket associated
5. Ask about attribution block
6. Ask about workflow execution summary
7. Check for repo PR template
8. Generate PR title and description
9. Create draft PR: `gh pr create --draft`
10. Report PR URL

## Branch Naming

Get username: `gh api user --jq '.login' 2>/dev/null`

Format: kebab-case
- With username + ticket: `<username>/<TICKET-ID>-description`
- With username only: `<username>/<description>`
- No username + ticket: `<TICKET-ID>-description`
- No username: `<description>`

## PR Title

- With Jira: `[<TICKET-ID>]: <concise description>`
- Without: `<concise description>`

## PR Template Discovery

### Check for Repo Template FIRST
`YOUR_SLACK_CHANNEL_ID``bash
cat .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || \
cat .github/pull_request_template.md 2>/dev/null || \
cat docs/PULL_REQUEST_TEMPLATE.md 2>/dev/null || \
cat PULL_REQUEST_TEMPLATE.md 2>/dev/null
`YOUR_SLACK_CHANNEL_ID``

### If Template Found
- Parse the template structure (headings, sections)
- Fill in each section with relevant content from commits
- Preserve template formatting and any required fields
- Add gif section if not present in template

### If No Template Found
Use default template below.

## Default PR Description Template

`YOUR_SLACK_CHANNEL_ID``
## What is this change doing?
<Describe what PR accomplishes>
<For organized commits, list by commit with title and SHA>

## Why is this change being made?
<Motivation, link Jira: [<TICKET-ID>](https://jira.gustocorp.com/browse/<TICKET-ID>)>

## How did you test this change?
<Unit tests added/updated, manual verifications>

## Screenshots
<Screenshots if UI changes, or "N/A">

## Related documentation
<Links or "N/A">

## Leave a gif(t) for the reviewer!
<ALWAYS include fun gif from giphy.com>

🤖 *Generated with [Claude Code](https://claude.com/claude-code)*
`YOUR_SLACK_CHANNEL_ID``

### Styling
- **Backticks** for code: function names, hooks, variables, flags, extensions
- **NO backticks** for SHAs - GitHub auto-links them
- **Bold** for file names, emphasis
- *Italics* for N/A sections

## AI Attribution Block (Optional)

Ask user: "Include AI workflow attribution block? (yes/no)"

If YES, prepend at TOP of description:
`YOUR_SLACK_CHANNEL_ID``
> [!IMPORTANT]
> **Built entirely by `gusto-dev-workflow-orchestrator` agent** - autonomous AI workflow from ticket to PR
>
> **What is gusto-dev-workflow-orchestrator?**
> A Claude Code agent that orchestrates the full development workflow autonomously. It coordinates between specialized sub-agents:
> - `gusto-senior-engineer` - implements code changes following codebase patterns
> - `gusto-code-reviewer` - reviews for quality, security, and best practices
> - `gusto-git-commit` - creates atomic, well-formatted commits
> - `gusto-pr-creator` - generates PR with proper description
>
> **How is this different from Claude Code built-ins?**
> Claude Code out-of-the-box is a general-purpose coding assistant. Our custom agents add:
> - **Gusto-specific knowledge**: MCP integrations with Jira, Confluence, Figma, and internal tools like `gusto-fe-north-star` and `workbench-assistant`
> - **Enforced workflow**: Structured checkpoints requiring human approval before proceeding (implementation → review → commit → PR)
> - **Codebase conventions**: Agents are trained on Gusto patterns, AGENTS.md guidelines, and team-specific practices
> - **Separation of concerns**: Each sub-agent has a focused responsibility vs one agent doing everything
>
> **Why build these agents?**
> - Consistency: Every PR follows the same quality gates regardless of which engineer runs the workflow
> - Guardrails: Human stays in control at decision points while AI handles repetitive execution
> - Leverage: Engineers can supervise multiple autonomous workflows in parallel
>
> The human engineer provides the ticket/task, approves at checkpoints, and the orchestrator handles everything else.
`YOUR_SLACK_CHANNEL_ID``

## Workflow Execution Summary (Optional)

Ask user: "Include workflow execution summary? (yes/no)"

If YES, insert AFTER attribution block (or at top if no attribution):

`YOUR_SLACK_CHANNEL_ID``
---

## Workflow Execution Summary

| Phase | Agent | Result |
|-------|-------|--------|
| 1. Implementation | `gusto-senior-engineer` | <result> |
| 2. Code Review | `gusto-code-reviewer` | <result> |
| 3. Refinement | `gusto-senior-engineer` | <result if applicable> |
| 4. Commit | `gusto-git-commit` | <result> |
| 5. PR Creation | `gusto-pr-creator` | This PR |

**Key Changes:**
<bullet list of main conversions/modifications>

**Orchestrator Value Demonstrated:**
1. **Automated handoffs** - Orchestrator directed each phase to the right specialist agent
2. **Quality gate** - Code review caught issues before commit
3. **Iterative refinement** - Seamlessly looped back to fix issues found in review
4. **User decision points** - Paused at key moments for user approval
5. **End-to-end delivery** - Single request → PR ready for merge

---
`YOUR_SLACK_CHANNEL_ID``

Customize:
- Remove phases not executed
- Adjust bullets to match actual workflow
- Add specific metrics (e.g., "14 files modified")

## Constraints

### ALWAYS
- Create PRs in DRAFT state
- Verify not on main/master before creating
- Confirm commits exist to include
- Validate PR created successfully
- Report PR URL on success

### NEVER
- Create ready-for-review PRs
- Skip gif section
- Silently continue on validation failure

## Error Handling

On failure:
1. Summarize in 1-3 sentences
2. Propose next action
3. Example: "Failed to create PR: branch has no commits ahead of main. Push commits first."

## Final Status (required)
- "PR created: [URL]"
- "No commits to create PR from."
- "Failed: [reason]. Next step: [action]"
