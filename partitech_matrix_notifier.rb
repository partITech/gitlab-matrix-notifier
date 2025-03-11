# frozen_string_literal: true
require 'open-uri'
require 'base64'
require 'json'

module PartitechIntegrations
  class PartitechMatrixNotifier < Integration
    include Base::ChatNotification

    # Matrix API endpoint format for sending messages
    MATRIX_HOSTNAME = "%{hostname}/_matrix/client/v3/rooms/%{roomId}/send/m.room.message/"

    # Configuration fields for the integration
    field :hostname,
      section: SECTION_TYPE_CONNECTION,
      help: 'Custom hostname of the Matrix server. Default: https://matrix-client.matrix.org.',
      placeholder: 'https://matrix-client.matrix.org',
      exposes_secrets: true,
      required: false

    field :token,
      section: SECTION_TYPE_CONNECTION,
      help: -> { s_('PartitechMatrixNotifier|Unique authentication token.') },
      non_empty_password_title: -> { s_('PartitechMatrixNotifier|New token') },
      non_empty_password_help: -> { s_('PartitechMatrixNotifier|Leave blank to use your current token.') },
      placeholder: 'syt-your-matrix-token',
      description: -> { _('The Matrix access token (e.g., syt-your-matrix-token).') },
      exposes_secrets: true,
      is_secret: true,
      required: true

    field :room,
      title: 'Room identifier',
      section: SECTION_TYPE_CONFIGURATION,
      help: -> {
        _("Unique identifier for the target room (e.g., !roomID:matrix.org).")
      },
      placeholder: 'Room ID',
      required: true

    field :notify_only_broken_pipelines,
      type: :checkbox,
      section: SECTION_TYPE_CONFIGURATION,
      description: -> { _('Send notifications only for failed pipelines.') },
      help: 'If checked, only broken pipelines will trigger a notification event.'

    field :branches_to_be_notified,
      type: :select,
      section: SECTION_TYPE_CONFIGURATION,
      title: -> { s_('PartitechMatrixNotifier|Branches to notify') },
      description: -> {
                     _('Choose branches to send notifications for. Options: all, default, protected, ' \
                       'or default_and_protected. Default: default.')
                   },
      choices: -> { branch_choices }

    # Validation rules
    with_options if: :activated? do
      validates :token, :room, presence: true
      validates :webhook, presence: true, public_url: true
    end

    before_validation :set_webhook

    # Integration metadata
    def self.title
      'Partitech Matrix Notifier'
    end

    def self.description
      s_("PartitechMatrixNotifier|Send notifications about project events to Matrix.")
    end

    def self.to_param
      'partitech_matrix_notifier'
    end

    def self.help
      build_help_page_url(
        'user/project/integrations/matrix.md',
        s_("PartitechMatrixNotifier|Send notifications about project events to Matrix.")
      )
    end

    def self.supported_events
      super - ['deployment']
    end

    private

    # Build the webhook URL for sending messages
    def set_webhook
      hostname = self.hostname.presence || 'https://matrix-client.matrix.org'
      return unless token.present? && room.present?

      self.webhook = format(MATRIX_HOSTNAME, hostname: hostname, roomId: room)
    end

    # Function to send notifications
    def notify(message, _opts)
      context = { no_sourcepos: true }.merge(project_level? ? { project: project } : { skip_project_check: true })

      # ✅ Function to upload an image to Matrix and return its accessible URL
      def upload_image_to_matrix(image_url)
        return nil unless image_url

        begin
          image_data = URI.open(image_url, 'rb') { |file| file.read }
          matrix_upload_url = "https://matrix.org/_matrix/media/r0/upload?access_token=#{token}"
          response = Gitlab::HTTP.post(matrix_upload_url, headers: { 'Content-Type' => 'image/png' }, body: image_data)

          if response.success?
            json_response = JSON.parse(response.body)
            json_response["content_uri"] # Return the Matrix-accessible image URL
          else
            puts "❌ Failed to upload avatar to Matrix: #{response.body}"
            nil
          end
        rescue => e
          puts "❌ Error uploading avatar: #{e.message}"
          nil
        end
      end

      # ✅ Retrieve the avatar URL for Matrix
      matrix_avatar_url = upload_image_to_matrix(message.user_avatar)
      user_avatar_html = matrix_avatar_url ? "<img src='#{matrix_avatar_url}' width='32' height='32' style='border-radius: 50%;'>" : ""

      # ✅ Format the message depending on the event type
      if message.is_a?(Integrations::ChatMessage::NoteMessage)
        formatted_text = <<~HTML
          #{user_avatar_html} <b>📌 New comment on #{message.target}</b><br>
          <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
          <b>Author:</b> #{message.user_name}<br>
          <b>📝 Comment:</b> #{message.note}<br>
          🔗 <a href="#{message.note_url}">View on GitLab</a>
        HTML

      elsif message.is_a?(Integrations::ChatMessage::PushMessage)
        commit_list = message.commits.map do |commit|
          author = commit['author']['name']
          timestamp = commit['timestamp']
          title = commit['title']
          commit_url = commit['url']

          <<~HTML
            🔹 <a href="#{commit_url}"><b>#{title}</b></a> by #{author} <i>(#{timestamp})</i><br>
          HTML
        end.join("")

        formatted_text = <<~HTML
          #{user_avatar_html} <b>🚀 New push to #{message.ref}</b><br>
          <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
          <b>Author:</b> #{message.user_name}<br>
          <b>📜 Commits:</b><br>
          #{commit_list}
          🔗 <a href="#{message.project_url}/-/compare/#{message.before}...#{message.after}">View changes</a>
        HTML

      else
        formatted_text = <<~HTML
          #{user_avatar_html} <b>🚀 New activity in #{message.project_name}</b><br>
          🔗 <a href="#{message.project_url}">View on GitLab</a>
        HTML
      end

      # ✅ Strip HTML tags for the plain text version
      plain_text = formatted_text.gsub(/<\/?[^>]*>/, '')

      # ✅ Construct the message payload
      body = {
        body: plain_text,
        msgtype: 'm.notice',
        format: 'org.matrix.custom.html',
        formatted_body: formatted_text.strip
      }.compact_blank

      # ✅ Send the notification to Matrix
      header = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{token}"
      }
      url = URI.parse(webhook)
      url.path << (Time.current.to_f * 1000).round.to_s
      response = Gitlab::HTTP.put(url, headers: header, body: Gitlab::Json.dump(body))

      response if response.success?
    end

    def custom_data(data)
      super(data).merge(markdown: true)
    end
  end
end

