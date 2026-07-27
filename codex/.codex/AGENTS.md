# Personal workflow

- Be extremely concise in interactions and commit messages; sacrifice grammar for concision.
- Use the laziest solution that works — shortest diff, stdlib over deps, YAGNI. No unrequested abstractions.

## Branches

- For ticket work, use `kelvin/<TICKET-ID>-<kebab-case-slug>`.
- Otherwise use `kelvin/<kebab-case-slug>`.

## Commits

- Use Conventional Commits: `<type>(<optional scope>): <description>`.
- Allowed types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `style`, `ci`, `perf`.
- Keep the subject a complete thought, at most 72 characters, with no trailing ellipsis.
- For ticket work, add a blank line followed by `[TICKET-ID]`.
- Local unpushed commits may be rebased and organized. Never force-push.

## Pull requests

- Create draft PRs only; never mark them ready, merge them, or bypass the repository merge process.
- Use title `[TICKET-ID]: <ticket title>`; look up the Jira title when possible.
- Read and fill the repository PR template. Use GitHub CLI as the default GitHub interface when authenticated.
- For a requested PR TODO, use GitHub checkbox markdown: `- [ ] <todo>`.
- End Codex-created PR descriptions with: `🤖 Generated with [Codex](https://openai.com/codex/)`.

## Precedence

- Follow closer repository `AGENTS.md` instructions for repository-specific commands, checks, and merge rules.
- These personal branch, commit, and draft-PR standards override tool or skill defaults such as `codex/` or `agent/` branch prefixes.
