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

    def hostgroup_ancestry_cache
      @hostgroup_ancestry_cache ||= begin
        hostgroup_facets = Facets.registered_facets.select { |_, facet| facet.has_hostgroup_configuration? }
        # return sorted list of ancestors with all facets in place
        ancestors.includes(hostgroup_facets.keys)
      end
    end

    def inherited_facet_attributes(facet_config)
      inherited_attributes = send(facet_config.name).inherited_attributes
      hostgroup_ancestry_cache.reverse_each do |hostgroup|
        hg_facet = hostgroup.send(facet_config.name)
        next unless hg_facet
        inherited_attributes.merge!(hg_facet.inherited_attributes) { |_, left, right| left || right }
      end

      inherited_attributes
    end
  end
end
