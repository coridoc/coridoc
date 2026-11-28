# frozen_string_literal: true

module Ceradoc
  module Reference
    class Edge < Lutaml::Model::Serializable
      # Options base class. Subclasses are typed value objects per kind —
      # never +:hash+. Value equality (==/eql?/hash) comes from
      # Lutaml::Model: class-aware, all attributes compared.
      class Options < Lutaml::Model::Serializable
        # Wire discriminator for the polymorphic options load (#384) —
        # the same first-class-type convention as the mirror node layer.
        attribute :type, :string
      end
    end
  end
end
