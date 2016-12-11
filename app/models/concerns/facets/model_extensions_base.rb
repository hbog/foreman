require 'facets'

module Facets
  module ModelExtensionsBase
    extend ActiveSupport::Concern

    included do
      def attributes
        hash = super

        # include all facet attributes by default
        facets_with_definitions.each do |facet, facet_definition|
          hash["#{facet_definition.name}_attributes"] = facet.attributes.reject { |key| %w(created_at updated_at).include? key }
        end
        hash
      end

      Facets::ManagedHostExtensions.refresh_facet_relations(self)
    end

    def self.included(mod)
      super

      register_overridable_methods(mod)
      register_refresh_facet_relations(mod)

      # This method is used to add all relation objects necessary for accessing facet from the host object.
      # It:
      # 1. Adds active record one to one association
      # 2. Adds the ability to set facet's attributes via Host#attributes= method
      # 3. Extends Host::Managed model with extension module defined by facet's configuration
      # 4. Includes facet in host's cloning mechanism
      # 5. Adds compatibility properties forwarders so old property calls will still work after moving them to a facet:
      #    host.foo # => will call Host.my_facet.foo
      mod.define_singleton_method :register_facet_relation do |klass, facet_config|
        return unless facet_config.has_configuration(facet_type)
        type_config = facet_config.send "#{facet_type}_configuration"
        facet_name = facet_config.name

        ModelExtensionsBase.extend_model_attributes(klass, type_config, facet_name, mod)
        ModelExtensionsBase.extend_model(klass, type_config, facet_name)
        ModelExtensionsBase.handle_migrations(klass, type_config, facet_name)

        on_register_facet_relation(klass, facet_config)
      end
    end

    def self.register_overridable_methods(mod)
      mod.define_singleton_method :base_model_id_field do
        raise 'You have to override "base_model_id_field" method for the model'
      end

      mod.define_singleton_method :base_model_symbol do
        raise 'You have to override "base_model_symbol" method for the model'
      end

      mod.define_singleton_method :facet_type do
        raise 'You have to override "facet_type" method for the model'
      end

      mod.define_singleton_method :on_register_facet_relation do |klass, facet_config|
        # callback method, will be called inside register_facet_relation
      end
    end

    def self.register_refresh_facet_relations(mod)
      mod.define_singleton_method :refresh_facet_relations do |klass|
        Facets.registered_facets.values.each do |facet_config|
          self.register_facet_relation(klass, facet_config)
        end
      end
    end

    def self.handle_migrations(klass, type_config, facet_name)
      return unless Foreman.in_rake?("db:migrate")
      klass.class_exec do
        # To prevent running into issues in old migrations when new facet is defined but not migrated yet.
        # We define it only when in migration to avoid this unnecessary checks outside for the migration
        define_method("#{facet_name}_with_migration_check") do
          if type_config.model.table_exists?
            send("#{facet_name}_without_migration_check")
          else
            logger.warn("Table for #{facet_name} not defined yet: skipping the facet data")
            nil
          end
        end
        alias_method_chain facet_name, :migration_check
      end
    end

    def self.extend_model(klass, type_config, facet_name)
      klass.class_exec do
        include type_config.extension if type_config.extension

        include_in_clone facet_name

        type_config.compatibility_properties.each do |prop|
          define_method(prop) { |*args| forward_property_call(prop, args, facet_name) }
        end if type_config.compatibility_properties
      end
    end

    def self.extend_model_attributes(klass, type_config, facet_name, mod)
      klass.class_exec(mod) do |extensions_module|
        has_one facet_name, :class_name => type_config.model.name, :foreign_key => extensions_module.base_model_id_field, :inverse_of => extensions_module.base_model_symbol
        accepts_nested_attributes_for facet_name, :update_only => true, :reject_if => :all_blank

        alias_method "#{facet_name}_attributes", facet_name
      end
    end

    def facets
      facets_with_definitions.keys
    end

    # This method will return a hash of facets for a specific host including the coresponding definitions.
    # The output should look like this:
    # { host.puppet_aspect => Facets.registered_facets[:puppet_aspect] }
    def facets_with_definitions
      Hash[(Facets.registered_facets.values.map do |facet_config|
        facet = send(facet_config.name)
        [facet, facet_config] if facet
      end).compact]
    end

    private

    def forward_property_call(property, args, facet)
      facet_instance = send(facet)
      return nil unless facet_instance

      facet_instance.send(property, *args)
    end
  end
end
