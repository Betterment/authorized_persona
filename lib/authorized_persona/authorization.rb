# frozen_string_literal: true

module AuthorizedPersona
  module Authorization
    extend ActiveSupport::Concern

    included do
      class_attribute :authorization_persona_class_name
      class_attribute :authorization_current_user_method
      class_attribute :authorized_actions
      self.authorized_actions = {}

      helper_method :authorization_current_user
    end

    class_methods do
      # Configure authorization for an authorized persona class
      def authorize_persona(class_name:, current_user_method: nil) # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity, Metrics/
        raise AuthorizedPersona::Error, "you can only configure authorization once" if authorization_persona_class_name.present?
        raise AuthorizedPersona::Error, "class_name must be a string" unless class_name.is_a?(String)
        raise AuthorizedPersona::Error, "current_user_method must be a symbol" if current_user_method && !current_user_method.is_a?(Symbol)

        self.authorization_persona_class_name = class_name

        unless authorization_persona < AuthorizedPersona::Persona
          raise AuthorizedPersona::Error, "#{class_name} must be an AuthorizedPersona::Persona"
        end

        model_name = if authorization_persona.respond_to?(:model_name)
                       authorization_persona.model_name.singular_route_key
                     else
                       authorization_persona.name.underscore
                     end
        self.authorization_current_user_method = current_user_method || :"current_#{model_name}"

        before_action :authorize!
      end

      # Grants replace all previous grants to avoid privilege leakage
      def grant(privileges) # rubocop:disable Metrics/AbcSize
        self.authorized_actions = privileges.map { |auth_tier, actions| [auth_tier.to_s, [actions].flatten.map(&:to_sym)] }.to_h

        tier_names = authorization_persona.authorization_tier_names
        extra_keys = authorized_actions.keys - authorization_persona.authorization_tier_names
        if extra_keys.present?
          raise AuthorizedPersona::Error, "invalid grant: #{authorization_persona_class_name} " \
                                          "has authorization tiers #{tier_names.join(', ')} but received extra keys: #{extra_keys.join(', ')}"
        end
      end

      def authorization_persona
        unless authorization_persona_class_name.is_a?(String)
          raise AuthorizedPersona::Error, "you must configure authorization, e.g. `authorize_persona class_name: 'User'`"
        end

        authorization_persona_class_name.constantize
      end

      def authorized?(current_user:, action:)
        raise AuthorizedPersona::Error, "#{current_user} is not a #{authorization_persona}" unless current_user.is_a?(authorization_persona)

        current_user.authorization_tier_at_or_above?(authorized_tier(action:))
      end

      def authorized_tier(action:)
        action = action.to_sym
        authorization_persona.authorization_tier_names.each do |tier|
          actions = authorized_actions[tier] || []
          return tier if actions == [:all] || actions.include?(action)
        end
        raise AuthorizedPersona::Error, "missing authorization grant for #{name}##{action}"
      end
    end

    def authorized?
      authorization_current_user && authorization_current_user.authorization_tier_at_or_above?(authorized_tier)
    end

    private

    def authorization_current_user
      unless authorization_current_user_method.is_a?(Symbol)
        raise AuthorizedPersona::Error, "you must configure authorization with a valid current_user method name, " \
                                        "e.g. `authorize_persona class_name: 'User', current_user_method: :my_custom_current_user`"
      end

      send(self.class.authorization_current_user_method)
    end

    def authorized_tier
      self.class.authorized_tier(action: params[:action])
    end

    def authorize!
      return if authorized?

      respond_to do |format|
        format.html do
          flash[:error] = 'You are not authorized to perform this action.'
          redirect_back fallback_location: '/', allow_other_host: false
        end
        format.json do
          render json: {}, status: :unauthorized
        end
        format.any do
          head :unauthorized
        end
      end
    end
  end
end
