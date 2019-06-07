require "authorized_persona/version"

require "rails"
require "active_model"

require "authorized_persona/persona"
require "authorized_persona/authorization"
require 'authorized_persona/view_helpers'

require "authorized_persona/railtie"

module AuthorizedPersona
  class Error < StandardError; end
end
