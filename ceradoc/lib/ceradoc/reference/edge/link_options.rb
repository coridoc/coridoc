# frozen_string_literal: true

module Ceradoc
  module Reference
    class Edge < Lutaml::Model::Serializable
      # Options for hyperlink edges.
      class LinkOptions < Edge::Options
        attribute :type, :string, default: 'LinkOptions'

        attribute :role, :string
      end
    end
  end
end
