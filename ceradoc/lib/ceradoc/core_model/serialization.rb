# frozen_string_literal: true

module Ceradoc
  module CoreModel
    # Polymorphic data-serialization registry (issue #384).
    #
    # CoreModel trees carry heterogeneous children (every `children`-style
    # collection is typed `Base`), so lutaml-model cannot rebuild them from
    # their own JSON/YAML/XML serializations without a class discriminator.
    # This file wires the pieces the framework needs:
    #
    # 1. `TYPE_TO_CLASS` — demodulized class name → full class name. The
    #    discriminator value on the wire is the demodulized name (the same
    #    convention ceradoc-mirror uses for its `type` field).
    # 2. `POLYMORPHIC` — the lutaml-model polymorphic config shared by
    #    every heterogeneous-collection mapping: reads the wire `type`
    #    discriminator and resolves it through `TYPE_TO_CLASS`.
    # 3. Generated `key_value` (json/yaml/hash) and `xml` mappings for
    #    every `Base` subclass, so each class serializes all of its
    #    attributes plus the discriminator, and heterogeneous collections
    #    dispatch to the concrete class on load.
    #
    # Heterogeneous collections are marked at their attribute declaration
    # with `polymorphic_class: true` (the framework's attribute-level
    # marker, e.g. StructuralElement#children); this walker reads that
    # marker (`Attribute#polymorphic?`) and attaches the rule-level
    # `polymorphic: POLYMORPHIC` dispatch config on both lanes.
    #
    # The tables and mappings are populated by the walker at the bottom of
    # this file, after every subclass constant is registered for autoload
    # in ../core_model.rb (load-time side effect, hence require_relative
    # there per repo convention). Adding a new CoreModel class = defining
    # it (any file, autoloaded) — the walker picks it up with no edits
    # here (OCP), the same contract as ceradoc-mirror's Node registry.
    #
    # Mappings are framework-generated through the lutaml-model DSL only
    # (repo law: no hand-rolled to_h/to_json/to_xml anywhere).
    #
    # Wire shapes:
    #
    #   JSON/YAML: { "type": "ParagraphBlock", "children": [ ... ] }
    #   XML:       <paragraph_block type="ParagraphBlock">
    #                <child type="TextElement">…</child>
    #              </paragraph_block>
    #
    #   Collection items repeat under their element name (attribute name,
    #   or the irregular override in XML_ITEM_NAMES), discriminated by the
    #   `type` attribute — the same convention as lutaml-model's
    #   polymorphic collection spec.
    TYPE_TO_CLASS = {} # rubocop:disable Style/MutableConstant -- populated by the walker, frozen after
    POLYMORPHIC = { attribute: 'type', class_map: TYPE_TO_CLASS }.freeze

    # Wire name of the class discriminator on every lane.
    TYPE_WIRE_KEY = 'type'

    # Irregular attribute name → XML item element name. Collections
    # otherwise repeat items under the attribute's own name (lutaml-model
    # spells repeated items that way, e.g. `<references>` in its
    # polymorphic collection spec).
    XML_ITEM_NAMES = { 'children' => 'child' }.freeze

    class << self
      def demodulized_name(klass)
        klass.name.to_s.split('::').last
      end

      def snake_case(class_name)
        class_name.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase
      end

      private

      # Register every `Base` subclass under `namespace` (recursing into
      # nested modules and nested model classes, e.g.
      # FrontmatterBlock::FrontmatterEntry) and declare its generated
      # key_value + xml mappings.
      def walk_model_tree(namespace, visited)
        namespace.constants.each do |name|
          k = namespace.const_get(name)
          next if visited.include?(k)

          visited << k
          if k.is_a?(Class) && k < Base
            register_model(k)
            walk_model_tree(k, visited)
          elsif k.is_a?(Module)
            walk_model_tree(k, visited)
          end
        end
      end

      def register_model(klass)
        full_name = klass.name
        return if full_name.nil?

        TYPE_TO_CLASS[demodulized_name(klass)] = full_name
        declare_mappings(klass)
      end

      # One shared rule-options computation per attribute: collections
      # marked `polymorphic_class: true` at declaration dispatch through
      # POLYMORPHIC on every lane; everything else uses the declared
      # element type as-is.
      # One shared rule-options computation per attribute. Two concerns:
      #
      # - polymorphic: collections marked `polymorphic_class: true` at
      #   declaration dispatch through POLYMORPHIC on every lane;
      #   everything else uses the declared element type as-is.
      # - render_empty: lutaml-model drops ""/[]/empty-model values from
      #   the wire by default, so a parsed "" title or an empty children
      #   array would come back as nil and break round-trip equality.
      #   Rendering empties keeps every set value on the wire.
      def rule_options(attr)
        options = { render_empty: true }
        options[:polymorphic] = POLYMORPHIC if attr.polymorphic?
        options
      end

      def declare_mappings(klass)
        attrs = klass.attributes
        declare_key_value_mapping(klass, attrs)
        declare_xml_mapping(klass, attrs)
      end

      def declare_key_value_mapping(klass, attrs)
        type_key = TYPE_WIRE_KEY
        rules = attrs.except(:type).transform_values { |attr| rule_options(attr) }
        klass.key_value do
          map type_key, to: :type, render_default: true
          rules.each do |name, options|
            map name.to_s, to: name, **options
          end
        end
      end

      def declare_xml_mapping(klass, attrs)
        root = snake_case(demodulized_name(klass))
        type_key = TYPE_WIRE_KEY
        rules = attrs.except(:type).to_h do |name, attr|
          [XML_ITEM_NAMES.fetch(name.to_s, name.to_s), [name, rule_options(attr)]]
        end
        klass.xml do
          element root
          map_attribute type_key, to: :type, render_default: true
          rules.each do |element_name, (attr_name, options)|
            map_element element_name, to: attr_name, **options
          end
        end
      end
    end

    # Populate the registry and generate the mappings now that every
    # subclass constant is registered for autoload in ../core_model.rb.
    # `const_get` triggers each autoload, so the walk is complete
    # regardless of the order files were first referenced in.
    walk_model_tree(CoreModel, [])
    TYPE_TO_CLASS.freeze
  end
end
