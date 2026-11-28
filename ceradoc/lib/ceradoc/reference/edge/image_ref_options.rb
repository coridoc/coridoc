# frozen_string_literal: true

module Ceradoc
  module Reference
    class Edge < Lutaml::Model::Serializable
      # Options for image references.
      class ImageRefOptions < Edge::Options
        attribute :type, :string, default: 'ImageRefOptions'

        attribute :alt_text, :string
        attribute :width, :string
        attribute :height, :string
        attribute :role, :string
      end
    end
  end
end
