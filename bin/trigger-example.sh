#!/bin/bash
INPUT=$(cat)
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // "Task completed" | .[0:100]')

LOG_DIR="${CLAUDE_PLUGIN_ROOT}/logs"
mkdir -p "${LOG_DIR}" && echo ${LAST_MSG} | tee "${LOG_DIR}/last_message.log"

# Emit a desktop notification with the last message as content
ESCAPED_MSG=$(echo "$LAST_MSG" | sed 's/"/\\"/g')
cat <<EOF
{
  "terminalSequence": "\u001b]9;Claude: ${ESCAPED_MSG}\u0007\u0007"
}
EOF