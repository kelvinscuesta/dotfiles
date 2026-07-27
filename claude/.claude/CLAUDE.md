- In all interactions and commit messages, be extremely concise and sacrifice grammar for the sake of concision.

# Coding style

- Use Ponytail mode (full) for all coding tasks — shortest working diff, stdlib over deps, YAGNI

# Pull requests


- Only ever create draft PRs, never in "ready for review" state.
- PR title format: `[{TICKET-ID}]: {ticket title}` — look up ticket title from Jira if possible, otherwise use a concise description derived from the commits
- When tagging Claude in GitHub, use '@claude'
- It is ok to rebase and organize commits on local branches that haven't been pushed to origin yet
- It is NOT ok to rebase on PR branches once a PR is out of Draft mode
- Always include this statement at the bottom of the PR description for PRs you create: "🤖 Generated with [Claude Code](https://claude.com/claude-code)"


 <pr-comment-rule>
 When I say to add a comment to a PR with a TODO on it, use the GitHub 'checkbox' markdown format to add the TODO. For instance:
   <example>
   - [ ] A description of the todo goes here
   </example>
 </pr-comment-rule>


# GitHub


- Your primary method for interacting with GitHub should be GitHub CLI


# Commits

- Use [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<optional scope>): <description>`
- Types: `feat`, `fix`, `chore`, `refactor`, `test`, `docs`, `style`, `ci`, `perf`
- Scope is optional, use for module/area name (e.g. `feat(auth): add login endpoint`)


# Git


- When creating branches:
 - Prefix them with 'kelvin/', to indicate they came from me
 - Use kebab-case for branch names

- `delta` is the default git pager (side-by-side, syntax highlighting)
- Use `git dft` for structural (AST-based) diffs via difftastic
- Use `git dfl` for structural log via difftastic

# Plans & Research


- Use ~/.claude/plans to store plans
- Use ~/.claude/research to store research
- Use markdown format for both
- At the end of each plan, give me a list of unresolved questions to answer, if any. Make the questions extremely concise. Sacrifice grammar for the sake of concision.


# LSP

- Always use the LSP tool when available for navigating code (go-to-definition, find references, hover for type info, diagnostics)
- Prefer LSP over text-based search (rg/grep) for finding symbol definitions, references, and type information
- Use LSP diagnostics to check for errors after edits instead of relying solely on running the compiler/linter

# Shell commands

- Use the Grep tool instead of `rg` or `grep` for searching file contents
- Use the Glob tool instead of `fd` or `find` for finding files
- Use `sg` (ast-grep) for structural code search/refactor — prefer over regex when matching code patterns (e.g. `sg -p 'console.log($$$ARGS)' -l js`)
- Use `difft` (difftastic) for structural diffs when line-based diff is too noisy
- Use `sd` instead of `sed` for find/replace — sane PCRE regex, use `-F` for literal strings
- Use `scc` to get quick codebase overviews (languages, LOC, complexity)
- Use `hyperfine` for benchmarking commands (e.g. `hyperfine --export-markdown results.md 'cmd1' 'cmd2'`)
- Never ask permission to run `rg`, `fd`, `sg`, `scc`, `sd`, `difft`, `head`, `tail`, or similar read-only commands — just run them
