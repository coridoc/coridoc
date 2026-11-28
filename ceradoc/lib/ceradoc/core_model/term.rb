# frozen_string_literal: true

module Ceradoc
  module CoreModel
    # Represents a definition term in a document
    #
    # Terms are used in definition lists, glossaries, and terminology
    # sections. They can have various types (acronym, symbol, preferred, etc.)
    # and support multi-language content.
    #
    # The term category is `term_type` (not `type`): `type` is the
    # CoreModel-wide class discriminator for data serialization
    # (issue #384) and is reserved on every Base subclass.
    #
    # @example Creating a simple term
    #   term = CoreModel::Term.new(
    #     text: "API",
    #     term_type: "acronym",
    #     definition: "Application Programming Interface"
    #   )
    #
    # @example Creating a multi-language term
    #   term = CoreModel::Term.new(
    #     text: "computer",
    #     term_type: "preferred",
    #     lang: "en",
    #     definition: "An electronic device for processing data"
    #   )
    class Term < Base
      # @!attribute text
      #   @return [String, nil] the term text
      attribute :text, :string

      # @!attribute term_type
      #   @return [String, nil] term type ('acronym', 'symbol', 'preferred', 'admitted', 'deprecated')
      attribute :term_type, :string

      # @!attribute lang
      #   @return [String] language code (default: 'en')
      attribute :lang, :string, default: -> { 'en' }

      # @!attribute definition
      #   @return [String, nil] definition of the term
      attribute :definition, :string

      # @!attribute source
      #   @return [String, nil] source reference for the term
      attribute :source, :string

      private

      def comparable_attributes
        super + %i[text term_type lang definition]
      end
    end
  end
end
