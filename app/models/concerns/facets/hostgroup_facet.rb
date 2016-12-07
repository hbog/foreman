require 'facets'

module Facets
  module HostgroupFacet
    extend ActiveSupport::Concern

    included do
      belongs_to :hostgroup
    end

    module ClassMethods
      def inherit_attributes(*attributes)
        attributes_to_inherit.concat(attributes).uniq!
      end

      def attributes_to_inherit
        @attributes_to_inherit ||= []
      end
    end

    def inherited_attributes
      attributes.slice(*self.class.attributes_to_inherit)
    end
  end
end
