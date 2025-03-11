
# Partitech Matrix Notifier

A **GitLab integration** for sending notifications to **Matrix rooms**, replacing the default **GitLab Matrix integration**.

## Features

- **Overwrites GitLab's built-in Matrix integration** to extend functionality.
- Sends notifications for GitLab events (push, merge requests, pipelines, issues, etc.).
- Supports **Matrix homeservers**.
- **HTML formatting** for enhanced readability.
- **Secure token authentication**.
- Includes a **standalone notification script (`matrix_notify.sh`)** for **deployment monitoring**.

## Installation

1. **Clone the repository**:

   ```sh
   git clone https://github.com/partitech/gitlab-matrix-notifier.git
   ```

2. **Run the installation script**:

   ```sh
   cd gitlab-matrix-notifier
   chmod +x install_partitech_matrix_notifier.sh
   sudo ./install_partitech_matrix_notifier.sh
   ```

3. **Restart GitLab** to apply changes:

   ```sh
   sudo gitlab-ctl restart
   ```

## Configuration

1. Go to **GitLab Admin Panel** → **Integrations**.
2. Select **Matrix**.
3. Enter:
   - **Matrix Server URL** (e.g., `https://matrix-client.matrix.org`)
   - **Access Token**
   - **Room ID**
4. Save and test the integration.

## Using the `matrix_notify.sh` Deployment Notification Script

### Purpose

The `matrix_notify.sh` script allows **sending real-time deployment notifications** to a **Matrix room**. It detects the current environment (`develop`, `recette`, `Production`, etc.) based on the hostname and sends a **formatted message**.

### Setup

1. **Copy the `matrix_notify.sh` script to your deployment server**:

   ```sh
   sudo cp matrix_notify.sh /usr/local/bin/matrix_notify.sh
   sudo chmod +x /usr/local/bin/matrix_notify.sh
   ```

2. **Edit the script** to configure:
   - `MATRIX_SERVER` → The Matrix homeserver (default: `https://matrix.org`).
   - `MATRIX_ROOM_ID` → The room ID where messages should be sent.
   - `MATRIX_ACCESS_TOKEN` → The authentication token.
   - Add or modify hostname mappings in the `case` statement to fit your infrastructure.

### Usage

Run the script **before or after deployment**:

```sh
/usr/local/bin/matrix_notify.sh
```

### Example Notification

When executed, the script sends the following message to the **Matrix room**:

```
🚀 The daily task has started on the **Production** server.
```

The script dynamically detects the hostname and **labels the environment accordingly**.

## Troubleshooting

If the integration does not appear in **GitLab**:
- Ensure **GitLab has restarted properly**.
- Check if the file `/opt/gitlab/embedded/service/gitlab-rails/app/models/integrations/matrix.rb` has been replaced.
- Look at logs using:

  ```sh
  sudo journalctl -u gitlab
  ```

If `matrix_notify.sh` does not send notifications:
- Verify **`MATRIX_SERVER`**, **`MATRIX_ROOM_ID`**, and **`MATRIX_ACCESS_TOKEN`**.
- Run it manually in verbose mode:

  ```sh
  bash -x /usr/local/bin/matrix_notify.sh
  ```

## License

MIT License.

