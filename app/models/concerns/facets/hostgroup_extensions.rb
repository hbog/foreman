require 'facets'

module Facets
  module HostgroupExtensions
    extend ActiveSupport::Concern
    include Facets::ModelExtensionsBase

    included do
      Facets.after_entry_created do |entry|
        if entry.has_hostgroup_configuration?
          Facets::HostgroupExtensions.register_facet_relation(Hostgroup, entry)
        end
      end
    end

    class << self
      def facet_type
        :hostgroup
      end

      def base_model_id_field
        :hostgroup_id
      end

      def base_model_symbol
        :hostgroup
      end

      def on_register_facet_relation(klass, facet_config)
        klass.class_exec do
          # add_ancestry_class_translation(facet_config.name.to_s => facet_config.hostgroup_configuration.model.name)
          # nested_attribute_for "#{facet_config.name}_id"
        end
      end
    end
  end
end
