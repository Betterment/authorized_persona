module AuthorizedPersona
  module Persona
    extend ActiveSupport::Concern

    included do
      if respond_to?(:where)
        def self.with_authorization_tier_at_or_above(tier)
          where(authorization_tier_attribute_name => authorization_tier_names.drop(authorization_tier_level(tier)))
        end
      end
    end

    class_methods do
      # Get the attribute name for authorization_tier
      def authorization_tier_attribute_name
        @authorization_tier_attribute_name || :authorization_tier
      end

      # Override the attribute name for authorization_tier
      def authorization_tier_attribute_name=(override)
        raise AuthorizedPersona::Error, "authorization_tier_attribute_name must be a symbol" unless override.is_a?(Symbol)

        @authorization_tier_attribute_name = override
      end

      # Label-first for use in forms
      def authorization_tier_collection
        @authorization_tier_collection = @authorization_tiers.invert
      end

      # Just the tier slugs for inclusion validations, etc.
      def authorization_tier_names
        @authorization_tier_names ||= @authorization_tiers.keys.map(&:to_s)
      end

      # Configure the authorization tiers in my_tier_slug: "My Tier Title And Description" form from lowest to highest privilege.
      def authorization_tiers(tiers) # rubocop:disable Metrics/AbcSize
        raise AuthorizedPersona::Error, "you can only define authorization tiers once" if instance_variable_defined?(:@authorization_tiers)

        if !tiers.is_a?(Hash) || !tiers.all? { |k, v| k.is_a?(Symbol) && v.is_a?(String) }
          raise('you must provide a hash of symbol tier names and string descriptions, e.g. " +
            trainee: "Trainee - limited access", staff: "Staff - regular access", admin: "Admin - full access"')
        end

        instance_methods = Module.new
        include instance_methods

        instance_methods.module_eval do
          tiers.keys.each do |tier|
            define_method "#{tier}_or_above?" do
              authorization_tier_at_or_above?(tier)
            end
          end
        end

        if respond_to?(:with_authorization_tier_at_or_above)
          class_methods = Module.new
          extend class_methods

          class_methods.module_eval do
            tiers.keys.each do |tier|
              define_method "#{tier}_or_above" do
                with_authorization_tier_at_or_above(tier)
              end
            end
          end
        end

        @authorization_tiers = tiers.freeze
      end

      private

      def authorization_tier_level(tier)
        authorization_tier_names.index(tier.to_s) || raise("Invalid authorization tier: #{tier}")
      end
    end

    def authorization_tier_at_or_above?(target_tier)
      attr_name = public_send(self.class.authorization_tier_attribute_name)
      self.class.send(:authorization_tier_level, attr_name) >= self.class.send(:authorization_tier_level, target_tier)
    end
  end
end
