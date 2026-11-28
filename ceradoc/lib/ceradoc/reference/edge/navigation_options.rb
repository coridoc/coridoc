# frozen_string_literal: true

module Ceradoc
  module Reference
    class Edge < Lutaml::Model::Serializable
      # Options specific to navigation edges (xref, anchor).
      class NavigationOptions < Edge::Options
        attribute :type, :string, default: 'NavigationOptions'

        attribute :tooltip, :string
      end
    end
  end
end
