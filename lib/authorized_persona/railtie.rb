module AuthorizedPersona
  class Railtie < Rails::Railtie
    initializer "authorized_persona.view_helpers" do
      ActionView::Base.send :include, AuthorizedPersona::ViewHelpers
    end
  end
end
