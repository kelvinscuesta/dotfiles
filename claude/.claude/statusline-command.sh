#!/usr/bin/env bash
input=$(cat)

# --- Parse JSON input ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // empty')
ctx_used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')

# --- Colors (ANSI-C quoting) ---
cyan=$'\033[36m'
magenta=$'\033[35m'
yellow=$'\033[33m'
green=$'\033[32m'
red=$'\033[31m'
blue=$'\033[34m'
dim=$'\033[2m'
reset=$'\033[0m'

sep="${dim} | ${reset}"

# --- Context color: green < 50%, yellow 50-75%, red > 75% ---
ctx_color="$green"
if [ -n "$ctx_used" ]; then
    ctx_int=${ctx_used%.*}
    [ "$ctx_int" -ge 50 ] 2>/dev/null && ctx_color="$yellow"
    [ "$ctx_int" -ge 75 ] 2>/dev/null && ctx_color="$red"
fi

parts=()

# --- Model (in brackets) ---
if [ -n "$model" ]; then
    parts+=("${dim}[${reset}${model}${dim}]${reset}")
fi

# --- Context bar ---
if [ -n "$ctx_used" ]; then
    ctx_int=${ctx_used%.*}
    bar_width=10
    filled=$(( ctx_int * bar_width / 100 ))
    empty=$(( bar_width - filled ))
    bar="${ctx_color}$(printf '▓%.0s' $(seq 1 $filled 2>/dev/null))$(printf '░%.0s' $(seq 1 $empty 2>/dev/null)) ${ctx_used}%${reset}"
    parts+=("$bar")
fi

# --- Directory ---
if [ -n "$cwd" ]; then
    display_dir="${cwd/#$HOME/\~}"
    parts+=("${cyan}${display_dir}${reset}")
fi

# --- Git: branch + dirty + jira ticket ---
if [ -n "$cwd" ] && cd "$cwd" 2>/dev/null && git rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git branch --show-current 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git_part="${magenta}${branch}${reset}"
        if ! git --no-optional-locks diff --quiet 2>/dev/null || ! git --no-optional-locks diff --cached --quiet 2>/dev/null; then
            git_part+="${red}*${reset}"
        fi
        if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null | head -1)" ]; then
            git_part+="${red}?${reset}"
        fi
        git_dir=$(git rev-parse --git-dir 2>/dev/null)
        if [[ "$git_dir" == *"/worktrees/"* ]]; then
            wt_name=$(basename "$git_dir")
            git_part+=" ${cyan}⑂ ${wt_name}${reset}"
        fi
        parts+=("$git_part")
        ticket=$(echo "$branch" | grep -oE '[A-Z]+-[0-9]+' | head -1)
        if [ -n "$ticket" ]; then
            parts+=("${yellow}${ticket}${reset}")
        fi
    fi
fi

# --- Tokens ---
if [ -n "$total_in" ] && [ -n "$total_out" ]; then
    total=$((total_in + total_out))
    if [ "$total" -ge 1000000 ]; then
        tok=$(awk "BEGIN{printf \"%.1fM\", $total/1000000}")
    else
        tok=$(awk "BEGIN{printf \"%.1fK\", $total/1000}")
    fi
    parts+=("${dim}${tok} tok${reset}")
fi

# --- Cost ---
if [ -n "$cost" ] && [ "$cost" != "null" ]; then
    cost_fmt=$(awk "BEGIN{printf \"%.2f\", $cost}")
    parts+=("${blue}\$${cost_fmt}${reset}")
fi

# --- Join with separator ---
output=""
for i in "${!parts[@]}"; do
    [ "$i" -gt 0 ] && output+="$sep"
    output+="${parts[$i]}"
done

echo "$output"
