require 'facets'

module Facets
  module ManagedHostExtensions
    extend ActiveSupport::Concern
    include Facets::ModelExtensionsBase

    included do
      configure_facet(:host, :host, :host_id)

      Facets.after_entry_created do |entry|
        register_facet_relation(entry) if entry.has_host_configuration?
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

    # This method will return attributes list augmented with attributes that are
    # set by the facet. Each registered facet will get opportunity to add its
    # own attributes to the list.
    def apply_facet_attributes(hostgroup, attributes)
      Facets.registered_facets.values.map do |facet_config|
        next unless facet_config.has_host_configuration?
        facet_config = facet_config.host_configuration
        facet_attributes = attributes["#{facet_config.name}_attributes"] || {}
        facet_attributes = facet_config.model.inherited_attributes(hostgroup, facet_attributes)
        attributes["#{facet_config.name}_attributes"] = facet_attributes unless facet_attributes.empty?
      end
      attributes
    end

    def populate_facet_fields(parser, type, source_proxy)
      Facets.registered_facets.values.each do |facet_config|
        facet_config.model.populate_fields_from_facts(self, parser, type, source_proxy)
      end
    end

  end
end
