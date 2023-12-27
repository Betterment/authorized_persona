# frozen_string_literal: true

require "authorized_persona/version"

require "rails"

require "authorized_persona/persona"
require "authorized_persona/authorization"
require 'authorized_persona/view_helpers'

require "authorized_persona/railtie"

module AuthorizedPersona
  class Error < StandardError; end
end
