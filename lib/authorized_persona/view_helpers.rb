# frozen_string_literal: true

module AuthorizedPersona
  module ViewHelpers
    def authorized_to?(action, resource)
      route = Rails.application.routes.named_routes[resource]
      raise AuthorizedPersona::Error, "Unable to determine route for #{resource}" if route.nil?

      controller_class = (route.defaults[:controller].camelize + 'Controller').constantize
      controller_class.authorized?(current_user: authorization_current_user, action:)
    end
  end
end
