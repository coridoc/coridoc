# frozen_string_literal: true

require 'lutaml/model'

module Ceradoc
  module Reference
    # Directed edge: a Content node references another Content via an Address.
    #
    # Every reference in ceradoc — navigation, citation, hyperlink,
    # include, image, footnote — is one Edge with a different +kind+.
    # The kind is a label for materialization; resolution is kind-agnostic.
    #
    #   Edge.new(
    #     kind: :navigation,
    #     address: Address.parse("ELF-5005-1#sec-3"),
    #     source_id: "para-42",
    #     label: "Section 3"
    #   )
    class Edge < Lutaml::Model::Serializable
      autoload :Kind, "#{__dir__}/edge/kind"
      autoload :Options, "#{__dir__}/edge/options"
      autoload :NavigationOptions,
               "#{__dir__}/edge/navigation_options"
      autoload :CitationOptions,
               "#{__dir__}/edge/citation_options"
      autoload :LinkOptions, "#{__dir__}/edge/link_options"
      autoload :IncludeOptions, "#{__dir__}/edge/include_options"
      autoload :ImageRefOptions, "#{__dir__}/edge/image_ref_options"
      autoload :FootnoteRefOptions,
               "#{__dir__}/edge/footnote_ref_options"

      attribute :kind, :string
      attribute :address, Ceradoc::Reference::Address
      attribute :source_id, :string
      attribute :label, :string
      # Options are per-kind subclasses of the (attribute-less) base —
      # heterogeneous like CoreModel children, so the data-serialization
      # lanes dispatch through a class_map discriminator (#384). Same
      # convention as CoreModel::Serialization: demodulized class name
      # on the wire under the 'type' key.
      OPTIONS_TYPE_TO_CLASS = {
        'NavigationOptions' => 'Ceradoc::Reference::Edge::NavigationOptions',
        'CitationOptions' => 'Ceradoc::Reference::Edge::CitationOptions',
        'LinkOptions' => 'Ceradoc::Reference::Edge::LinkOptions',
        'IncludeOptions' => 'Ceradoc::Reference::Edge::IncludeOptions',
        'ImageRefOptions' => 'Ceradoc::Reference::Edge::ImageRefOptions',
        'FootnoteRefOptions' => 'Ceradoc::Reference::Edge::FootnoteRefOptions'
      }.freeze
      OPTIONS_POLYMORPHIC = { attribute: 'type', class_map: OPTIONS_TYPE_TO_CLASS }.freeze

      # Every options subclass renders its discriminator (default-valued
      # attributes are omitted by default mappings, so the mapping is
      # explicit) — the load side dispatches through OPTIONS_POLYMORPHIC.
      OPTIONS_TYPE_TO_CLASS.each_value do |options_name|
        options_klass = Object.const_get(options_name)
        options_klass.key_value do
          map 'type', to: :type, render_default: true
          options_klass.attributes.each_key do |name|
            next if name == :type

            map name.to_s, to: name
          end
        end
      end

      attribute :options, Ceradoc::Reference::Edge::Options

      key_value do
        map 'kind', to: :kind
        map 'address', to: :address
        map 'source_id', to: :source_id
        map 'label', to: :label
        map 'options', to: :options, polymorphic: OPTIONS_POLYMORPHIC
      end

      class << self
        # Build an Edge with the given kind. Options are coerced to the
        # kind's options class (if any) via the Kind registry — never
        # hand-rolled. Raises UnknownKindError for kinds that were never
        # registered — external kinds register via +register_kind+ (OCP).
        def build(kind:, address:, source_id: nil, label: nil, options: nil)
          entry = Kind.entry_for(kind)
          unless entry
            raise Ceradoc::Reference::UnknownKindError,
                  "Unknown reference kind #{kind.inspect} — " \
                  'register it via Edge.register_kind'
          end

          new(
            kind: kind.to_s,
            address: address,
            source_id: source_id,
            label: label,
            options: coerce_options(options, entry.options_class)
          )
        end

        def register_kind(name, options_class: nil)
          Kind.register(name, options_class: options_class)
        end

        def kinds
          Kind.names
        end

        private

        def coerce_options(value, options_class)
          klass = options_class || Options
          return klass.new if value.nil?
          return value if value.is_a?(klass)

          klass.new(value)
        end
      end
    end
  end
end
