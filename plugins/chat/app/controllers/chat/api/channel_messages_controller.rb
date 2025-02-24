# frozen_string_literal: true

class Chat::Api::ChannelMessagesController < Chat::ApiController
  def index
    with_service(::Chat::ListChannelMessages) do
      on_success { render_serialized(result, ::Chat::MessagesSerializer, root: false) }
      on_failed_policy(:can_view_channel) { raise Discourse::InvalidAccess }
      on_failed_policy(:target_message_exists) { raise Discourse::NotFound }
      on_model_not_found(:channel) { raise Discourse::NotFound }
    end
  end

  def destroy
    with_service(Chat::TrashMessage) { on_model_not_found(:message) { raise Discourse::NotFound } }
  end

  def restore
    with_service(Chat::RestoreMessage) do
      on_model_not_found(:message) { raise Discourse::NotFound }
    end
  end

  def update
    with_service(Chat::UpdateMessage) do
      on_success { render json: success_json.merge(message_id: result[:message].id) }
      on_model_not_found(:message) { raise Discourse::NotFound }
      on_model_errors(:message) do |model|
        render_json_error(model.errors.map(&:full_message).join(", "))
      end
    end
  end

  def create
    Chat::MessageRateLimiter.run!(current_user)

    with_service(Chat::CreateMessage) do
      on_success { render json: success_json.merge(message_id: result[:message].id) }
      on_failed_policy(:no_silenced_user) { raise Discourse::InvalidAccess }
      on_model_not_found(:channel) { raise Discourse::NotFound }
      on_failed_policy(:allowed_to_join_channel) { raise Discourse::InvalidAccess }
      on_model_not_found(:channel_membership) { raise Discourse::InvalidAccess }
      on_failed_policy(:ensure_reply_consistency) { raise Discourse::NotFound }
      on_failed_policy(:allowed_to_create_message_in_channel) do |policy|
        render_json_error(policy.reason)
      end
      on_failed_policy(:ensure_valid_thread_for_channel) do
        render_json_error(I18n.t("chat.errors.thread_invalid_for_channel"))
      end
      on_failed_policy(:ensure_thread_matches_parent) do
        render_json_error(I18n.t("chat.errors.thread_does_not_match_parent"))
      end
      on_model_errors(:message) do |model|
        render_json_error(model.errors.map(&:full_message).join(", "))
      end
    end
  end
end
