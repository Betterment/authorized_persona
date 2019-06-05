require 'spec_helper'

RSpec.describe PCA::Authorization do
  let(:base_controller_class) do
    Class.new.tap do |k|
      allow(k).to receive(:helper_method)
      allow(k).to receive(:before_action)
    end
  end

  let(:klass) do
    Class.new(base_controller_class) do
      include PCA::Authorization

      attr_reader :current_user

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
      include PCA::Persona

      attr_reader :authorization_tier

      def initialize(authorization_tier: nil)
        @authorization_tier = authorization_tier
      end

      authorization_tiers(
        one: "1",
        two: "2",
        three: "3",
        four: "4"
      )

      define_singleton_method :model_name do
        model_name
      end
    end
  end

  it "registers authorization_current_user as a helper method" do
    klass
    expect(base_controller_class).to have_received(:helper_method).with(:authorization_current_user)
  end

  it "registers the authorize! hook" do
    klass
    expect(base_controller_class).to have_received(:before_action).with(:authorize!)
  end

  describe ".authorize_persona" do
    it "blows up with no class_name" do
      expect { klass.authorize_persona }.to raise_error(/missing keyword/)
    end
    it "blows up with a non-string class_name" do
      expect { klass.authorize_persona(class_name: :foo) }.to raise_error(/must be a string/)
    end
    it "blows up if class_name doesn't resolve to a PCA::Persona" do
      stub_const("User", Class.new)
      expect { klass.authorize_persona(class_name: "User") }.to raise_error(/must be a PCA::Persona/)
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
  end

  describe ".grant" do
    it "normalizes privileges hash into authorized_actions" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        one: "index",
        two: %w(create update),
        three: "all"
      )

      expect(klass.authorized_actions).to eq(
        "one" => [:index],
        "two" => %i(create update),
        "three" => [:all]
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
          bologne: "all"
        )
      }.to raise_error(/invalid grant.*extra keys.*bologne/)
    end

    it "clears previous grants on unrelated actions when overridden" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        one: "index",
        two: %w(create update),
        three: "all"
      )
      klass.grant(
        two: %w(create update)
      )

      expect(klass.authorized_actions).to eq(
        "two" => %i(create update)
      )
    end

    it "inherits grants from superclasses" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        one: "index"
      )

      subclass = Class.new(klass)
      expect(subclass.authorized_actions).to eq(
        "one" => [:index]
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
    it "blows up if provided current_user isn't the correct authorization_persona" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")

      cheeseburger = double("Cheeseburger") # rubocop:disable RSpec/VerifiedDoubles
      expect { klass.authorized?(current_user: cheeseburger, action: "show") }.to raise_error(/Cheeseburger.* is not a User/)
    end

    it "is not authorized if authorized level is higher than current_user's" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(four: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.authorized?(current_user: user, action: "show")).to eq false
    end

    it "is authorized if authorized level is same as current_user's" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
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
        three: "show"
      )

      expect(klass.authorized_tier(action: "show")).to eq("three")
    end

    it "returns the lowest tier grant matching the provided action as a symbol" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        four: :show,
        three: :show
      )

      expect(klass.authorized_tier(action: :show)).to eq("three")
    end

    it "returns the lowest tier matching :all" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(
        three: :show,
        two: :all
      )

      expect(klass.authorized_tier(action: :show)).to eq("two")
    end
  end

  describe "#authorized?" do
    it "blows up if no grants exist for an action" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")

      user = user_class.new(authorization_tier: "four")

      expect { klass.new(current_user: user, action: "show").authorized? }.to raise_error(/missing authorization grant/)
    end

    it "is not authorized if authorized level is higher than current_user's" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(four: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "show")).not_to be_authorized
    end

    it "is authorized if authorized level is lower than current_user's" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(two: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "show")).to be_authorized
    end

    it "is authorized if authorized level is at current_user's" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(three: :show)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "show")).to be_authorized
    end

    it "is authorized for an arbitrary action if level action is set to :all" do
      stub_const("User", user_class)
      klass.authorize_persona(class_name: "User")
      klass.grant(three: :all)

      user = user_class.new(authorization_tier: "three")

      expect(klass.new(current_user: user, action: "bumpity")).to be_authorized
    end
  end
end
