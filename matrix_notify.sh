#!/bin/bash

# Configuration variables (should be set via environment variables or a .env file)
MATRIX_SERVER="${MATRIX_SERVER:-https://matrix.org}"
MATRIX_ROOM_ID="${MATRIX_ROOM_ID:-!your-room-id:matrix.org}"
MATRIX_ACCESS_TOKEN="${MATRIX_ACCESS_TOKEN:-your-access-token}"

# Retrieve hostname
HOSTNAME=$(hostname)

# Define environment name based on hostname (modify as needed)
case $HOSTNAME in
  "your-dev-hostname")
    ENV_NAME="Development"
    ;;
  "your-staging-hostname")
    ENV_NAME="Staging"
    ;;
  "your-production-hostname")
    ENV_NAME="Production"
    ;;
  *)
    ENV_NAME="Unknown ($HOSTNAME)"
    ;;
esac

START_TIME=$(date +%s)

# ✅ Construct the Matrix message
MESSAGE="🚀 The deployment task has started on **$ENV_NAME**"

# ✅ Construct the Matrix request URL
TIMESTAMP=$(date +%s)
MATRIX_URL="$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM_ID/send/m.room.message/$TIMESTAMP?access_token=$MATRIX_ACCESS_TOKEN"

# ✅ Construct the JSON payload
JSON_PAYLOAD=$(cat <<EOF
{
  "msgtype": "m.text",
  "body": "$MESSAGE",
  "format": "org.matrix.custom.html",
  "formatted_body": "<b>$MESSAGE</b>"
}
EOF
)

# ✅ Send the notification to Matrix
curl -X PUT "$MATRIX_URL" \
     -H "Content-Type: application/json" \
     -d "$JSON_PAYLOAD"

