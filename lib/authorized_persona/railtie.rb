# frozen_string_literal: true

module AuthorizedPersona
  class Railtie < Rails::Railtie
    initializer "authorized_persona.view_helpers" do
      ActionView::Base.include AuthorizedPersona::ViewHelpers
    end
  end
end
