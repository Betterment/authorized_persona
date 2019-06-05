require 'spec_helper'

RSpec.describe PCA::Persona do
  let(:klass) do
    Class.new do
      include PCA::Persona

      def initialize(authorization_tier)
        @authorization_tier = authorization_tier
      end

      attr_reader :authorization_tier
    end
  end

  describe ".authorization_tier_attribute_name=" do
    it "blows up if not a symbol" do
      expect { klass.authorization_tier_attribute_name = "string" }.to raise_error(/symbol/)
    end

    it "works if a symbol" do
      expect { klass.authorization_tier_attribute_name = :funky_bunch }.not_to raise_error
    end
  end

  describe ".authorization_tier_attribute_name" do
    it "returns :authorization_tier unless overridden" do
      expect(klass.authorization_tier_attribute_name).to eq :authorization_tier
    end

    it "returns override if overridden" do
      klass.authorization_tier_attribute_name = :funky_bunch
      expect(klass.authorization_tier_attribute_name).to eq :funky_bunch
    end
  end

  describe ".authorization_tier_collection" do
    it "returns title/descriptions first" do
      klass.authorization_tiers(
        one: "1 description",
        two: "2 description",
        three: "3 description"
      )
      expect(klass.authorization_tier_collection).to eq(
        "1 description" => :one,
        "2 description" => :two,
        "3 description" => :three
      )
    end
  end

  describe ".authorization_tier_names" do
    it "returns stringified keys" do
      klass.authorization_tiers(
        one: "1",
        two: "2",
        three: "3"
      )
      expect(klass.authorization_tier_names).to eq(%w(one two three))
    end
  end

  describe ".authorization_tiers" do
    it "blows up with a non-hash argument" do
      expect { klass.authorization_tiers("foo") }.to raise_error(/hash/)
    end

    it "blows up with a non-symbol key" do
      expect { klass.authorization_tiers("foo" => "bar") }.to raise_error(/symbol/)
    end

    it "blows up with a non-string value" do
      expect { klass.authorization_tiers(foo: :bar) }.to raise_error(/string/)
    end

    it "works if set up appropriately" do
      expect { klass.authorization_tiers(foo: "bar") }.not_to raise_error
    end

    it "blows up when called twice" do
      expect { klass.authorization_tiers(foo: "bar") }.not_to raise_error
      expect { klass.authorization_tiers(one_more: "thing") }.to raise_error(/once/)
    end
  end

  describe "#[tier]_or_above? and aiuthorization_tier_at_or_above?" do
    before do
      klass.authorization_tiers(
        trainee: "Trainee - limited access",
        staff: "Staff - regular access",
        admin: "Admin - full access"
      )
    end

    context "with a trainee" do
      subject { klass.new("trainee") }

      it "is trainee_or_above" do
        expect(subject).to be_trainee_or_above
        expect(subject).to be_authorization_tier_at_or_above('trainee')
      end

      it "is not staff_or_above" do
        expect(subject).not_to be_staff_or_above
        expect(subject).not_to be_authorization_tier_at_or_above('staff')
      end

      it "is not admin_or_above" do
        expect(subject).not_to be_admin_or_above
        expect(subject).not_to be_authorization_tier_at_or_above('admin')
      end
    end

    context "with an admin" do
      subject { klass.new("admin") }

      it "is trainee_or_above" do
        expect(subject).to be_trainee_or_above
        expect(subject).to be_authorization_tier_at_or_above('trainee')
      end

      it "is staff_or_above" do
        expect(subject).to be_staff_or_above
        expect(subject).to be_authorization_tier_at_or_above('staff')
      end

      it "is admin_or_above" do
        expect(subject).to be_admin_or_above
        expect(subject).to be_authorization_tier_at_or_above('admin')
      end
    end

    context "with an invalid tier" do
      subject { klass.new("nonexistant") }

      it "blows up attempting to determine if trainee_or_above" do
        expect { subject.trainee_or_above? }.to raise_error(/Invalid authorization tier: nonexistant/)
        expect { subject.authorization_tier_at_or_above?('trainee') }.to raise_error(/Invalid authorization tier: nonexistant/)
      end
    end
  end

  context "with a class with a custom attribute name" do
    let(:klass) do
      Class.new do
        include PCA::Persona

        self.authorization_tier_attribute_name = :role
        authorization_tiers(
          level_one: "One - ah ah ah",
          level_two: "Two - ah ah ah",
          level_three: "Three! - ah ah ah"
        )

        def initialize(role)
          @role = role
        end

        attr_reader :role
      end
    end

    context "with a level_two" do
      subject { klass.new("level_two") }
      it "is level_two_or_above" do
        expect(subject).to be_level_two_or_above
      end

      it "isn't level_three_or_above" do
        expect(subject).not_to be_level_three_or_above
      end
    end
  end
end
