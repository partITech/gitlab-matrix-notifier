# frozen_string_literal: true
require 'open-uri'
require 'base64'
require 'json'

module Integrations
  class Matrix < Integration
    include Base::ChatNotification

    MATRIX_HOSTNAME = "%{hostname}/_matrix/client/v3/rooms/%{roomId}/send/m.room.message/"

    field :hostname,
      section: SECTION_TYPE_CONNECTION,
      help: 'Custom hostname of the Matrix server. The default value is https://matrix-client.matrix.org.',
      placeholder: 'https://matrix-client.matrix.org',
      exposes_secrets: true,
      required: false

    field :token,
      section: SECTION_TYPE_CONNECTION,
      help: -> { s_('MatrixIntegration|Unique authentication token.') },
      non_empty_password_title: -> { s_('MatrixIntegration|New token') },
      non_empty_password_help: -> { s_('MatrixIntegration|Leave blank to use your current token.') },
      placeholder: 'syt-zyx57W2v1u123ew11',
      description: -> { _('The Matrix access token (for example, syt-zyx57W2v1u123ew11).') },
      exposes_secrets: true,
      is_secret: true,
      required: true

    field :room,
      title: 'Room identifier',
      section: SECTION_TYPE_CONFIGURATION,
      help: -> {
        _("Unique identifier for the target room (in the format !qPKKM111FFKKsfoCVy:matrix.org).")
      },
      placeholder: 'room ID',
      required: true

    field :notify_only_broken_pipelines,
      type: :checkbox,
      section: SECTION_TYPE_CONFIGURATION,
      description: -> { _('Send notifications for broken pipelines.') },
      help: 'If selected, successful pipelines do not trigger a notification event.'

    field :branches_to_be_notified,
      type: :select,
      section: SECTION_TYPE_CONFIGURATION,
      title: -> { s_('Integrations|Branches for which notifications are to be sent') },
      description: -> {
                     _('Branches to send notifications for. Valid options are all, default, protected, ' \
                       'and default_and_protected. The default value is default.')
                   },
      choices: -> { branch_choices }

    with_options if: :activated? do
      validates :token, :room, presence: true
      validates :webhook, presence: true, public_url: true
    end

    before_validation :set_webhook

    def self.title
      'Matrix notifications'
    end

    def self.description
      s_("MatrixIntegration|Send notifications about project events to Matrix.")
    end

    def self.to_param
      'matrix'
    end

    def self.help
      build_help_page_url(
        'user/project/integrations/matrix.md',
        s_("MatrixIntegration|Send notifications about project events to Matrix.")
      )
    end

    def self.supported_events
      super - ['deployment']
    end

    private

    def set_webhook
      hostname = self.hostname.presence || 'https://matrix-client.matrix.org'

      return unless token.present? && room.present?

      self.webhook = format(MATRIX_HOSTNAME, hostname: hostname, roomId: room)
    end

    def notify(message, _opts)
      context = { no_sourcepos: true }.merge(project_level? ? { project: project } : { skip_project_check: true })
	
		  
	  # ✅ Function to send an image to Matrix and retrieve an accessible URL
	  def upload_image_to_matrix(image_url)
	    return nil unless image_url

	    begin
	      image_data = URI.open(image_url, 'rb') { |file| file.read }
	      matrix_upload_url = "https://matrix.org/_matrix/media/r0/upload?access_token=#{token}"
	      response = Gitlab::HTTP.post(matrix_upload_url, headers: { 'Content-Type' => 'image/png' }, body: image_data)

	      if response.success?
		json_response = JSON.parse(response.body)
		json_response["content_uri"] # Renvoie l'URL Matrix de l'image
	      else
		puts "Échec de l'upload de l'avatar sur Matrix : #{response.body}"
		nil
	      end
	    rescue => e
	      puts "Erreur lors de l'upload de l'avatar : #{e.message}"
	      nil
	    end
	  end

	  # ✅ Récupération de l'URL de l'avatar sur Matrix
	  matrix_avatar_url = upload_image_to_matrix(message.user_avatar)
	  user_avatar_html = matrix_avatar_url ? "<img src='#{matrix_avatar_url}' width='32' height='32' style='border-radius: 50%;'>" : ""

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
	      added_files = commit['added'].any? ? "➕ #{commit['added'].join(', ')}<br>" : ""
	      modified_files = commit['modified'].any? ? "✏️ #{commit['modified'].join(', ')}<br>" : ""
	      removed_files = commit['removed'].any? ? "❌ #{commit['removed'].join(', ')}<br>" : ""

	      <<~HTML
		🔹 <a href="#{commit_url}"><b>#{title}</b></a> by #{author} <i>(#{timestamp})</i><br>
		#{added_files}#{modified_files}#{removed_files}
	      HTML
	    end.join("")

	    formatted_text = <<~HTML
	      #{user_avatar_html} <b>🚀 New push on #{message.ref}</b><br>
	      <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
	      <b>Author:</b> #{message.user_name}<br>
	      <b>📜 Commits:</b><br>
	      #{commit_list}
	      🔗 <a href="#{message.project_url}/-/compare/#{message.before}...#{message.after}">View the difference</a>
	    HTML
 	  elsif message.is_a?(Integrations::ChatMessage::MergeMessage)
		action_emoji = message.action == "close" ? "🔴 Closed" : "🟢 Reopened"

		formatted_text = <<~HTML
		  #{user_avatar_html} <b>🔄 Merge Request #{action_emoji} :</b> <a href="#{message.project_url}/-/merge_requests/#{message.merge_request_iid}">#{message.title}</a><br>
		  <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
		  <b>Author:</b> #{message.user_name}<br>
		  <b>🔀 From:</b> #{message.source_branch} → #{message.target_branch}<br>
		  🔗 <a href="#{message.project_url}/-/merge_requests/#{message.merge_request_iid}">View Merge Request</a>
		HTML
			
 	  elsif message.is_a?(Integrations::ChatMessage::MergeMessage)
 	        pipeline_status = message.status.capitalize
		status_emoji = message.status == "success" ? "✅" : "❌"

		formatted_text = <<~HTML
		  #{user_avatar_html} <b>#{status_emoji} Pipeline #{pipeline_status} :</b> <a href="#{message.pipeline_url}">##{message.pipeline_id}</a><br>
		  <b>Projet :</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
		  <b>Auteur :</b> #{message.user_name}<br>
		  🔗 <a href="#{message.pipeline_url}">Voir la pipeline</a>
		HTML
 	  
	  elsif message.is_a?(Integrations::ChatMessage::WikiPageMessage)
	  		message_debug = JSON.pretty_generate(message.as_json) rescue message.inspect
			formatted_text = case message.action
			  when "created"
				<<~HTML
				  #{user_avatar_html} <b>📖 New Wiki Page Created:</b> <a href="#{message.wiki_page_url}">#{message.title}</a><br>
				  <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
				  <b>Author:</b> #{message.user_name}<br>
				  <b>📝 Description:</b> #{message.description || "No description"}<br>
				  🔗 <a href="#{message.wiki_page_url}">View Wiki Page</a>
				HTML

			  when "edited"
				<<~HTML
				  #{user_avatar_html} <b>📖 Wiki Page Updated:</b> <a href="#{message.wiki_page_url}">#{message.title}</a><br>
				  <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
				  <b>Author:</b> #{message.user_name}<br>
				  <b>📝 Description:</b> #{message.description || "No description"}<br>
				  🔗 <a href="#{message.wiki_page_url}">View Wiki Page</a><br>
				  🔄 <a href="#{message.diff_url}">View Changes</a>
				HTML

			  when "deleted", nil
				<<~HTML
				  #{user_avatar_html} <b>❌ Wiki Page Deleted:</b> #{message.title}<br>
				  <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
				  <b>Author:</b> #{message.user_name}<br>
				  🔗 <a href="#{message.wiki_page_url}">(Residual link to the page)</a><br>
				  🔄 <a href="#{message.diff_url}">View changes before deletion</a>
				HTML

			  else
				<<~HTML
				  #{user_avatar_html} <b>📖 Unknown Activity on a Wiki Page:</b> <a href="#{message.wiki_page_url}">#{message.title}</a><br>
				  <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
				  <b>Author:</b> #{message.user_name}<br>
				  <b>📝 Description:</b> #{message.description || "No description"}<br>
				  🔗 <a href="#{message.wiki_page_url}">View Wiki Page</a>
				HTML
			end

	  else
		  if message.object_kind == "issue" && message.action == "open"
			formatted_text = <<~HTML
			  #{user_avatar_html} <b>🆕 New Issue Opened:</b> <a href="#{message.issue_url}">#{message.title}</a><br>
			  <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
			  <b>Author:</b> #{message.user_name}<br>
			  <b>📝 Description:</b> #{message.description}<br>
			  🔗 <a href="#{message.issue_url}">View Issue</a>
			HTML

		  elsif message.object_kind == "issue" && %w[close reopen].include?(message.action)
		    action_emoji = message.action == "close" ? "🔒" : "🔓"
		    state_text = message.action == "close" ? "closed" : "reopen"

			formatted_text = <<~HTML
			  #{user_avatar_html} <b>#{action_emoji} Issue #{state_text}:</b> <a href="#{message.issue_url}">#{message.title}</a><br>
			  <b>Project:</b> <a href="#{message.project_url}">#{message.project_name}</a><br>
			  <b>Author:</b> #{message.user_name}<br>
			  <b>📝 Description:</b> #{message.description}<br>
			  🔗 <a href="#{message.issue_url}">View Issue</a>
			HTML
		  else
			# 🔍 Debug for any other unknown message type
			message_debug = JSON.pretty_generate(message.as_json) rescue message.inspect
			formatted_text = <<~HTML
			  #{user_avatar_html} <b>🚀 New Unhandled Activity in #{message.project_name}</b><br>
			  🔗 <a href="#{message.project_url}">View on GitLab</a><br>
			  <pre>#{message_debug}</pre>
			HTML
		  end
	  end

	  # ✅ Remove HTML tags for the plain text version
	  plain_text = formatted_text.gsub(/<\/?[^>]*>/, '')

	  # ✅ Build the message for Matrix
	  body = {
	    body: plain_text,
	    msgtype: 'm.notice',
	    format: 'org.matrix.custom.html',
	    formatted_body: formatted_text.strip
	  }.compact_blank 
	  
	  
      
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
