#!/bin/bash

# Define paths for overwriting the existing GitLab Matrix integration
GITLAB_INTEGRATION_DIR="/opt/gitlab/embedded/service/gitlab-rails/app/models/integrations"
TARGET_FILE="$GITLAB_INTEGRATION_DIR/matrix.rb"
SCRIPT_NAME="partitech_matrix_notifier.rb"

# Ensure running as root
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root!" 
   exit 1
fi

echo "🚀 Installing Partitech Matrix Notifier and overwriting GitLab's default Matrix integration..."

# ✅ Ensure the directory exists
mkdir -p "$GITLAB_INTEGRATION_DIR"

# ✅ Backup existing GitLab Matrix integration (just in case)
if [[ -f "$TARGET_FILE" ]]; then
    mv "$TARGET_FILE" "$TARGET_FILE.bak"
    echo "🔄 Backup of original Matrix integration created: $TARGET_FILE.bak"
fi

# ✅ Copy the integration script to overwrite GitLab's existing Matrix integration
cp "$SCRIPT_NAME" "$TARGET_FILE"
chmod 644 "$TARGET_FILE"

# ✅ Set correct permissions
chown git:git "$TARGET_FILE"

# ✅ Restart GitLab services to apply changes
echo "🔄 Restarting GitLab services..."
gitlab-ctl restart

echo "✅ Installation completed! GitLab's Matrix integration has been replaced by Partitech Matrix Notifier."
