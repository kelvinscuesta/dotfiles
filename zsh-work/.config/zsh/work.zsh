# Gusto work configuration

# Load Gusto shell init (mise, brew, git-duet, etc.)
source "$HOME/.gusto/init.sh"

# AWS
export AWS_PROFILE=payroll-exp-eng-gusto-main

# Secrets (APOLLO_KEY, etc.)
[ -f ~/.secrets ] && source ~/.secrets

# Workspace navigation
alias zp='cd ~/workspace/zenpayroll'
alias hi='cd ~/workspace/hawaiian-ice'
alias aips='cd ~/workspace/ai-platform-services'
alias web='cd ~/workspace/web'

# Frontend
alias fe="yarn nx dev gusto"
alias runpretty='prettier --write $(git diff --cached --name-only --diff-filter=ACMR | grep -E "\.(js|jsx|ts|tsx|json|css|scss|md|yaml|yml|graphql)$")'
alias yarntest="yarn test --runTestsByPath"

# Yarn: hardlink node_modules to a shared global cache — dedups disk across the
# web clone + worktrees (overrides checked-in .yarnrc.yml locally)
export YARN_NM_MODE=hardlinks-global
export YARN_ENABLE_GLOBAL_CACHE=true


# claude code
export ENABLE_LSP_TOOLS=1
