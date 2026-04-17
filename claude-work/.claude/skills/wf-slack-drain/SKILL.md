---
name: wf-slack-drain
description: Post queued workflow audit entries to #your-automation-channel. The workflow server fills ~/.claude/workflow/slack_queue.jsonl with noteworthy events; this skill batches them into a single Slack message and truncates the queue. Use when user says "/wf-slack-drain", "sync slack", "post workflow events to slack", or runs on a loop (e.g., `/loop 5m /wf-slack-drain`).
---

# wf-slack-drain

Drain the server's Slack queue — batch audit entries into one Slack post.

## Procedure

### 1. Read the queue

```bash
QUEUE=~/.claude/workflow/slack_queue.jsonl
if [[ ! -s "$QUEUE" ]]; then
  echo "slack queue empty"
  exit 0
fi
cat "$QUEUE"
```

Each line is a JSON object: `{ ts, action, message }`.

### 2. Skip if empty

If queue file is empty or missing, report "nothing to post" and stop.

### 3. Format batch

Group entries chronologically. Format each as a single line:
```
`HH:MM` *ACTION* — message
```

Cap at 40 entries per post (older entries land in next drain). If more than 40, take first 40, leave rest.

### 4. Build Slack message

Format as one message:

```
📋 *Workflow activity* — <N> events

• `10:32` *POLL:JIRA* — found 2 new tickets: PAY-38012, PAY-38015
• `10:33` *CLASSIFY* — PAY-38012 → ready
• `10:45` *APPROVE* — PAY-38012 approved by user
• `10:46` *RUN:START* — implement → /wf-implement PAY-38012
• `11:02` *RUN:OK* — implement exit=0
• `11:02` *JIRA:TRANSITION* — PAY-38012 In Progress → In Review
```

### 5. Post via MCP

Use `mcp__claude_ai_Slack_Gusto_Offical__slack_send_message` with:
- `channel_id`: `YOUR_SLACK_CHANNEL_ID` (your automation channel)
- `message`: formatted batch

### 6. Truncate queue (only after successful post)

```bash
# Keep entries beyond the batch we posted
if [[ "$POSTED_COUNT" -lt "$TOTAL_COUNT" ]]; then
  tail -n +$((POSTED_COUNT + 1)) "$QUEUE" > "$QUEUE.tmp" && mv "$QUEUE.tmp" "$QUEUE"
else
  : > "$QUEUE"  # truncate
fi
```

Only truncate if Slack post returned success. On failure, leave queue for retry.

### 7. Output

```
📬 Posted <N> events to #your-automation-channel
Queue now: <remaining> events
```

## Never

- Never post if the queue is empty (be quiet)
- Never truncate before successful Slack post
- Never mention >5000 chars (Slack limit) — truncate message text if needed
