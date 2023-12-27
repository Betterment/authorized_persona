# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuthorizedPersona::ViewHelpers do
  let(:klass) do
    Class.new do
      include AuthorizedPersona::ViewHelpers

      def authorization_current_user
        "user_1"
      end
    end
  end

  let(:rails_app) { instance_double(Rails::Application, routes:) }
  let(:routes) { instance_double(ActionDispatch::Routing::RouteSet, named_routes: { foo: route }) }
  let(:route) { instance_double(ActionDispatch::Journey::Route, defaults: { controller: "foos" }) }

  let(:foos_controller_class) { Class.new }

  before do
    allow(Rails).to receive(:application).and_return(rails_app)
  end

  subject { klass.new }

  describe "#authorized_to?" do
    it "blows up if the route can't be located" do
      allow(rails_app.routes).to receive(:named_routes).and_return({})
      expect { subject.authorized_to?(:create, :foo) }.to raise_error(/Unable to determine route/)
    end

    it "blows up if it can't find a class matching the route's controller name" do
      expect { subject.authorized_to?(:create, :foo) }.to raise_error(/uninitialized constant FoosController/)
    end

    it "is authorized when the controller says so" do
      stub_const("FoosController", foos_controller_class)
      allow(foos_controller_class).to receive(:authorized?).and_return(true)

      expect(subject).to be_authorized_to(:create, :foo)
      expect(foos_controller_class).to have_received(:authorized?).with(current_user: "user_1", action: :create)
    end

    it "isn't authorized when the controller says no" do
      stub_const("FoosController", foos_controller_class)
      allow(foos_controller_class).to receive(:authorized?).and_return(false)

      expect(subject).not_to be_authorized_to(:create, :foo)
      expect(foos_controller_class).to have_received(:authorized?).with(current_user: "user_1", action: :create)
    end
  end
end
