require 'spec_helper'

RSpec.describe AuthorizedPersona::Authorization do
  let(:base_controller_class) do
    Class.new.tap do |k|
      allow(k).to receive(:helper_method)
      allow(k).to receive(:before_action)
    end
  end

  let(:klass) do
    Class.new(base_controller_class) do
      include AuthorizedPersona::Authorization

      attr_reader :current_user
      private :current_user

      def initialize(current_user: nil, action: nil)
        @current_user = current_user
        @action = action
      end

      def params
        { action: @action }
      end
    end
  end

  let(:user_model_name) { instance_double(ActiveModel::Name, singular_route_key: "user") }

  let(:user_class) do
    model_name = user_model_name
    Class.new do
      include AuthorizedPersona::Persona

      attr_reader :authorization_tier

      def initialize(authorization_tier: nil)
        @authorization_tier = authorization_tier
      end

      authorization_tiers(
        one: "1",
        two: "2",
        three: "3",
        four: "4",
      )

      define_singleton_method :model_name do
        model_name
      end
    end
  end

  describe "for a non-activemodel persona" do
    let(:non_activemodel_user_class) do
      Class.new do
        include AuthorizedPersona::Persona

        def self.name
          "NonActiveModelUser"
        end

        attr_reader :authorization_tier

        def initialize(authorization_tier: nil)
          @authorization_tier = authorization_tier
        end

        authorization_tiers(
          one: "1",
          two: "2",
          three: "3",
          four: "4",
        )
      end
    end

    it "sets its authorization_current_user_method to match class name" do
      stub_const("SomeUser", non_activemodel_user_class)
      klass.authorize_persona class_name: "SomeUser"
      expect(klass.authorization_current_user_method).to eq(:current_non_active_model_user)
    end
  end

  it "registers authorization_current_user as a helper method" do
    klass
    expect(base_controller_class).to have_received(:helper_method).with(:authorization_current_user)
  end

  it "doesn't eagerly register the authorize! hook to allow the consumer to set hook ordering" do
    klass
    expect(base_controller_class).not_to have_received(:before_action).with(:authorize!)
  end

  describe ".authorize_persona" do
    it "blows up with no class_name" do
      expect { klass.authorize_persona }.to raise_error(/missing keyword/)
    end

    it "blows up with a non-string class_name" do
      expect { klass.authorize_persona(class_name: :foo) }.to raise_error(/must be a string/)
    end

    it "blows up if class_name doesn't resolve to a AuthorizedPersona::Persona" do
      stub_const("User", Class.new)
      expect { klass.authorize_persona(class_name: "User") }.to raise_error(/must be an AuthorizedPersona::Persona/)
    end

    it "blows up if current_user_method is defined and not a symbol" do
      stub_const("User", user_class)

      expect { klass.authorize_persona(class_name: "User", current_user_method: "foo") }.to raise_error(/must be a symbol/)
    end

    it "is fine with no current_user_method" do
      stub_const("User", user_class)

      expect { klass.authorize_persona(class_name: "User") }.not_to raise_error
    end

    it "is fine with a specified current_user_method" do
      stub_const("User", user_class)

      expect { klass.authorize_persona(class_name: "User", current_user_method: :custom_current_user) }.not_to raise_error
    end

    it "blows up if called twice" do
      stub_const("User", user_class)

      klass.authorize_persona(class_name: "User")
      expect { klass.authorize_persona(class_name: "User") }.to raise_error(/configure authorization once/)
    end

    it "registers the authorize! hook to allow the consumer to set hook ordering" do
      stub_const("User", user_class)

      expect(base_controller_class).not_to have_received(:before_action).with(:authorize!)

      klass.authorize_persona(class_name: "User")

      expect(base_controller_class).to have_received(:before_action).with(:authorize!)
    end
  end

  describe ".grant" do
    it "normalizes privileges hash into authorized_actions" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        one: "index",
        two: %w(create update),
        three: "all",
      )

      expect(klass.authorized_actions).to eq(
        "one" => [:index],
        "two" => %i(create update),
        "three" => [:all],
      )
    end

    it "blows up with nonexistent tier names" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      expect {
        klass.grant(
          one: "index",
          two: %w(create update),
          three: "all",
          bologne: "all",
        )
      }.to raise_error(/invalid grant.*extra keys.*bologne/)
    end

    it "clears previous grants on unrelated actions when overridden" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        one: "index",
        two: %w(create update),
        three: "all",
      )
      klass.grant(
        two: %w(create update),
      )

      expect(klass.authorized_actions).to eq(
        "two" => %i(create update),
      )
    end

    it "inherits grants from superclasses" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        one: "index",
      )

      subclass = Class.new(klass)
      expect(subclass.authorized_actions).to eq(
        "one" => [:index],
      )
    end
  end

  describe ".authorization_persona" do
    it "blows up with docs if you haven't called authorize" do
      expect { klass.authorization_persona }.to raise_error(/must configure authorization/)
    end

    it "returns the constantized class_name passed to authorize" do
      stub_const("User", user_class)

      klass.authorize_persona(class_name: "User")

      expect(klass.authorization_persona).to eq user_class
    end
  end

  describe ".authorized?" do
    before do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
    end

    it "blows up if provided current_user isn't the correct authorization_persona" do
      cheeseburger = double("Cheeseburger") # rubocop:disable RSpec/VerifiedDoubles
      expect { klass.authorized?(current_user: cheeseburger, action: "show") }.to raise_error(/Cheeseburger.* is not a User/)
    end

    it "is not authorized if authorized level is higher than current_user's" do
      klass.grant(four: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.authorized?(current_user: user, action: "show")).to eq false
    end

    it "is authorized if authorized level is same as current_user's" do
      klass.grant(three: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.authorized?(current_user: user, action: "show")).to eq true
    end
  end

  describe ".authorized_tier" do
    it "blows up if no grants exist for an action" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")

      expect { klass.authorized_tier(action: :show) }.to raise_error(/missing authorization grant/)
    end

    it "returns the lowest tier grant matching the provided action as a string" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        four: "show",
        three: "show",
      )

      expect(klass.authorized_tier(action: "show")).to eq("three")
    end

    it "returns the lowest tier grant matching the provided action as a symbol" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        four: :show,
        three: :show,
      )

      expect(klass.authorized_tier(action: :show)).to eq("three")
    end

    it "returns the lowest tier matching :all" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        three: :show,
        two: :all,
      )

      expect(klass.authorized_tier(action: :show)).to eq("two")
    end
  end

  describe "#authorized?" do
    let(:authorize_opts) { { class_name: "User" } }

    before do
      stub_const("User", user_class)
      klass.authorize_persona(**authorize_opts)
    end

    it "returns false when user is nil" do
      expect(klass.new(current_user: nil, action: "show")).not_to be_authorized
    end

    it "blows up if no grants exist for an action" do
      user = user_class.new(authorization_tier: "four")

      expect { klass.new(current_user: user, action: "show").authorized? }.to raise_error(/missing authorization grant/)
    end

    it "is not authorized if authorized level is higher than current_user's" do
      klass.grant(four: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "show")).not_to be_authorized
    end

    it "is authorized if authorized level is lower than current_user's" do
      klass.grant(two: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "show")).to be_authorized
    end

    it "is authorized if authorized level is at current_user's" do
      klass.grant(three: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "show")).to be_authorized
    end

    it "is authorized for an arbitrary action if level action is set to :all" do
      klass.grant(three: :all)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "bumpity")).to be_authorized
    end

    context "with a specified current_user_method" do
      let(:authorize_opts) { { class_name: "User", current_user_method: :custom_current_user } }

      it "does not raise an error" do
        user = user_class.new(authorization_tier: "four")
        klass.define_method(:custom_current_user) { user }
        klass.grant(four: 'show')

        expect { klass.new(current_user: nil, action: "show").authorized? }.not_to raise_error
      end
    end

    context 'with a non-symbol current_user method' do
      let(:authorize_opts) { { class_name: "User" } }

      it 'blows up' do
        klass.grant(four: 'show')
        klass.authorization_current_user_method = 'current_user'

        expect { klass.new(current_user: nil, action: "show").authorized? }.to raise_error(
          AuthorizedPersona::Error,
          "you must configure authorization with a valid current_user method name, " \
          "e.g. `authorize_persona class_name: 'User', current_user_method: :my_custom_current_user`",
        )
      end
    end
  end

  describe '#authorize!' do
    before do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(one: "show")
    end

    let(:format) do
      fmt = string_format
      Class.new {
        define_method(:html) do |&block|
          instance_eval(&block) if fmt == 'html'
        end

        define_method(:json) do |&block|
          instance_eval(&block) if fmt == 'json'
        end

        define_method(:any) do |&block|
          instance_eval(&block)
        end
      }.new
    end
    let(:base_controller_class) do
      fmt = format
      k = Class.new do
        define_method(:respond_to) do |&block|
          block.call(fmt)
        end
      end
      allow(k).to receive(:helper_method)
      allow(k).to receive(:before_action)
      k
    end
    let(:current_user) { nil }
    let(:flash) { {} }

    before do
      allow(format).to receive(:flash).and_return(flash)
      allow(format).to receive(:redirect_back)
      allow(format).to receive(:render)
      allow(format).to receive(:head)
    end

    subject { klass.new(current_user: current_user, action: "show") }

    context 'when request format is HTML' do
      let(:string_format) { 'html' }

      it "sets a flash message and redirects back" do
        subject.__send__(:authorize!)
        expect(format).to have_received(:flash)
        expect(flash).to eq(error: "You are not authorized to perform this action.")
        expect(format).to have_received(:redirect_back).with(fallback_location: "/", allow_other_host: false)
        expect(format).not_to have_received(:render)
        expect(format).to have_received(:head).with(:unauthorized)
      end

      context 'when user is authorized' do
        let(:current_user) { user_class.new(authorization_tier: "one") }

        it "does not trigger any redirect or unauthorized behavior" do
          subject.__send__(:authorize!)
          expect(format).not_to have_received(:flash)
          expect(format).not_to have_received(:redirect_back)
          expect(format).not_to have_received(:render)
          expect(format).not_to have_received(:head)
        end
      end
    end

    context 'when request format is JSON' do
      let(:string_format) { 'json' }

      it "sets a flash message and redirects back" do
        subject.__send__(:authorize!)
        expect(format).not_to have_received(:flash)
        expect(format).not_to have_received(:redirect_back)
        expect(format).to have_received(:render).with(json: {}, status: :unauthorized)
        expect(format).to have_received(:head).with(:unauthorized)
      end

      context 'when user is authorized' do
        let(:current_user) { user_class.new(authorization_tier: "one") }

        it "does not trigger any redirect or unauthorized behavior" do
          subject.__send__(:authorize!)
          expect(format).not_to have_received(:flash)
          expect(format).not_to have_received(:redirect_back)
          expect(format).not_to have_received(:render)
          expect(format).not_to have_received(:head)
        end
      end
    end
  end
end
