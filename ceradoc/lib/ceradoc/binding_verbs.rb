# frozen_string_literal: true

module Ceradoc
  # Declarative hook verbs (bindings schema 1.2, ceradoc#386 — stage 2 of
  # the SSOT tables).
  #
  # Most `via:` hooks are shapes, not semantics: a wrapper capture is
  # unwrapped, fields are promoted out of a child capture, a capture is
  # stringified. A verb names one such shape in the table
  # (`via: {verb: promote, ...}`) and is interpreted here, generically,
  # on the inflated attributes — the table carries no executable
  # content. A rule whose shape needs one semantic step beyond its verb
  # appends `then:` naming a registered hook, which receives the verb's
  # result; everything genuinely semantic stays a named hook.
  #
  # The verbs are pure data operations: they build no models, parse no
  # syntax and hold no format vocabulary. That is the line between a
  # verb and a hook — a verb is a shape the inflater could run for any
  # format; a hook is a step the format owns. {BindingInflater} compiles
  # a rule's table entry (string keys, schema vocabulary) into the
  # symbolized configs these methods take.
  module BindingVerbs
    # The catalog: verb name => the config keys its table entry accepts.
    VERBS = {
      'unwrap' => %w[key],
      'flatten' => %w[key],
      'promote' => %w[source attrs],
      'string' => %w[capture]
    }.freeze

    # Config keys each verb's table entry must carry.
    VERB_REQUIRED = { 'promote' => %w[attrs], 'string' => %w[capture] }.freeze

    # Fields a `promote` attribute spec accepts.
    SPEC_FIELDS = %w[key as strip wrap default].freeze

    # Field converters a `promote` attribute spec accepts (`as:` values).
    # `copy` assigns the (inflated) field as is; the others coerce.
    CONVERTERS = {
      copy: ->(value) { value },
      string: :to_s.to_proc,
      string_or_nil: ->(value) { value&.to_s },
      joined: ->(value) { value.is_a?(Array) ? value.map(&:to_s).join : value.to_s }
    }.freeze

    module_function

    # `unwrap`: the node is a wrapper. The named capture (default: the
    # sole one) passes through as the inflation result.
    def unwrap(attributes, key: nil)
      key ||= sole_capture(attributes, 'unwrap')
      attributes.fetch(key)
    end

    # `flatten`: the node wraps one child capture whose hash entries are
    # the attributes themselves. The entries are the verb's result.
    def flatten(attributes, key: nil)
      key ||= sole_capture(attributes, 'flatten')
      child = attributes.fetch(key)
      raise ArgumentError, "verb flatten: capture #{key.inspect} is not a mapping" unless child.is_a?(Hash)

      child
    end

    # `promote`: build attributes by copying fields out of a source (a
    # child capture's hash, or the node's own captures when no source is
    # named), each through a declared converter. Returns only the
    # promoted attributes; the inflater merges them over the rule's
    # defaults. `attrs` maps attribute => compiled spec.
    def promote(attributes, source: nil, attrs: {})
      from = source ? attributes.fetch(source) : attributes
      attrs.transform_values { |spec| convert(from, spec) }
    end

    # `string`: the inflation result is one capture's string.
    def string(attributes, capture:)
      attributes.fetch(capture).to_s
    end

    def convert(source, spec)
      value = source[spec[:key]]
      converted = CONVERTERS.fetch(spec[:as] || :copy).call(value)
      converted = converted.strip if spec[:strip]
      return converted unless spec[:wrap]

      # `wrap` mirrors the truthiness of the field itself, not its
      # converted string: an absent field falls back, an empty string
      # still wraps.
      value ? [converted] : spec.fetch(:default, [])
    end

    def sole_capture(attributes, verb)
      keys = attributes.keys
      raise ArgumentError, "verb #{verb}: needs `key` when the node has #{keys.size} captures" unless keys.one?

      keys.first
    end
  end
end
