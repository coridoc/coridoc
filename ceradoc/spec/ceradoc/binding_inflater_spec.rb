# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe Ceradoc::BindingInflater do
  let(:rule_model) { Struct.new(:style, :child, keyword_init: true) }
  let(:binding) do
    described_class::Binding.new(keys: %i[rule child], model: rule_model, captures: { child: :child },
                                 defaults: { style: 'x' })
  end
  let(:residual) { ->(node) { [:residual, node] } }
  let(:inflater) { described_class.new(bindings: [binding]) }

  it 'instantiates the bound model for a node whose keys match the binding' do
    result = inflater.inflate({ rule: true, child: 'leaf' }, &residual)
    expect(result).to eq(rule_model.new(style: 'x', child: 'leaf'))
  end

  it 'returns the hook result as is for a model-less binding' do
    hook = ->(attrs) { [:tree, attrs[:child]] }
    modelless = described_class::Binding.new(keys: %i[rule child], model: nil, captures: { child: :child },
                                             defaults: {}, via: hook)
    result = described_class.new(bindings: [modelless]).inflate({ rule: true, child: 'leaf' }, &residual)
    expect(result).to eq([:tree, 'leaf'])
  end

  it 'hands an unbound node to the residual untouched' do
    node = { other: 'v' }
    expect(inflater.inflate(node, &residual)).to eq([:residual, node])
  end

  it 'does not bind a node that carries extra keys' do
    node = { rule: true, child: 'a', ial: '.c' }
    expect(inflater.inflate(node, &residual)).to eq([:residual, node])
  end

  it 'recurses into captured collections, binding or falling through per node' do
    node = { rule: true, child: [{ rule: true, child: 'a' }, { other: 1 }] }
    result = inflater.inflate(node, &residual)
    expect(result.child).to eq([rule_model.new(style: 'x', child: 'a'), [:residual, { other: 1 }]])
  end

  it 'coerces string-like captures to String' do
    slice = Parsanol::Slice.new(0, 'leaf')
    result = inflater.inflate({ rule: true, child: slice }, &residual)
    expect(result.child).to be_a(String).and eq('leaf')
  end

  it 'resolves a lazily supplied model at first use' do
    lazy = described_class::Binding.new(keys: [:rule], model: -> { rule_model }, captures: {}, defaults: { style: 'l' })
    expect(described_class.new(bindings: [lazy]).inflate({ rule: true }, &residual)).to eq(rule_model.new(style: 'l'))
  end

  it 'assigns raw captures as captured, never inflating or sending them to the residual' do
    raw = described_class::Binding.new(keys: %i[rule child], model: rule_model, captures: {}, defaults: {},
                                       raw: { child: :child })
    subtree = [{ rule: true, child: 'a' }, { other: 1 }]
    result = described_class.new(bindings: [raw]).inflate({ rule: true, child: subtree }, &residual)
    expect(result.child).to equal(subtree)
  end

  it 'reports whether a node is bound without instantiating' do
    expect(inflater.bound?({ rule: true, child: 'a' })).to be(true)
    expect(inflater.bound?({ other: 1 })).to be(false)
  end

  it 'falls through everything when no bindings exist' do
    node = { rule: true, child: 'a' }
    expect(described_class.new(bindings: []).inflate(node, &residual)).to eq([:residual, node])
  end

  it 'builds the model from the attributes a via hook returns' do
    hooked = described_class::Binding.new(
      keys: [:wrapped], model: rule_model, captures: { wrapped: :wrapped }, defaults: {},
      via: ->(attributes) { { style: attributes[:wrapped][:inner].upcase } }
    )
    result = described_class.new(bindings: [hooked]).inflate({ wrapped: { inner: 'a' } }, &:itself)
    expect(result).to eq(rule_model.new(style: 'A'))
  end
end

RSpec.describe Ceradoc::BindingInflater, '.from_table' do
  let(:model) { Struct.new(:style, :child, keyword_init: true) }
  let(:table) do
    { 'version' => 1,
      'rules' => { 'r' => { 'keys' => %w[rule kid], 'model' => 'M', 'captures' => {},
                            'children' => { 'child' => 'kid' }, 'defaults' => { 'style' => 'x' } } } }
  end
  let(:inflater) { described_class.from_table(table, models: ->(name) { { 'M' => model }.fetch(name) }) }

  it 'builds bindings from the embedded table, resolving the model by name' do
    result = inflater.inflate({ rule: true, kid: { rule: true, kid: 'leaf' } }) { |n| n }
    expect(result).to eq(model.new(style: 'x', child: model.new(style: 'x', child: 'leaf')))
  end

  it 'binds nothing for a missing table' do
    node = { rule: true }
    expect(described_class.from_table(nil, models: ->(_) {}).inflate(node) { :residual }).to eq(:residual)
  end

  it 'rejects an unknown table version' do
    expect { described_class.from_table(table.merge('version' => 2), models: ->(_) {}) }
      .to raise_error(ArgumentError, /version/)
  end
end

RSpec.describe Ceradoc::BindingInflater, '.from_table with a 1.1 table' do
  let(:model) { Struct.new(:style, :ial, keyword_init: true) }
  let(:hook) { ->(attrs) { { style: attrs[:raw_field].to_s.upcase, ial: attrs[:ial] } } }
  let(:hooks) { { 'decorate' => hook } }
  let(:table) do
    { 'version' => '1.1',
      'hooks' => { 'decorate' => 'Hooks#decorate' },
      'rules' => {
        'hooked' => { 'keys' => %w[rule raw_field], 'model' => 'M', 'raw' => { 'raw_field' => 'raw_field' },
                      'via' => 'decorate' },
        'plain' => { 'keys' => %w[other], 'model' => 'M', 'defaults' => { 'style' => 'p' } }
      } }
  end
  let(:models) { ->(name) { { 'M' => model }.fetch(name) } }

  it 'resolves a via hook by name through the registry hash and builds the model from its result' do
    result = described_class.from_table(table, models: models, hooks: hooks)
                            .inflate({ rule: true, raw_field: 'leaf' }) { |n| n }
    expect(result).to eq(model.new(style: 'LEAF'))
  end

  it 'accepts a registry callable resolving names instead of a hash' do
    inflater = described_class.from_table(table, models: models, hooks: ->(name) { hooks.fetch(name) })
    expect(inflater.inflate({ rule: true, raw_field: 'leaf' }) { |n| n }).to eq(model.new(style: 'LEAF'))
  end

  it 'honors scoped: true by passing the inflate context to the hook' do
    scoped_hook = ->(_attrs, scope) { { style: scope } }
    table['rules']['hooked'].merge!('via' => 'scoped_hook', 'raw' => {}, 'keys' => %w[rule], 'scoped' => true)
    table['hooks']['scoped_hook'] = 'Hooks#scoped'
    result = described_class.from_table(table, models: models, hooks: { 'scoped_hook' => scoped_hook })
                            .inflate({ rule: true }, :ctx) { |n| n }
    expect(result).to eq(model.new(style: :ctx))
  end

  it 'builds the hook result as is when the rule has no model' do
    table['rules']['hooked'].merge!('model' => nil, 'raw' => { 'raw_field' => 'raw_field' })
    result = described_class.from_table(table, models: models, hooks: hooks)
                            .inflate({ rule: true, raw_field: 'leaf' }) { |n| n }
    expect(result).to eq(style: 'LEAF', ial: nil)
  end

  it 'expands optional captures into one binding per key set' do
    table['rules']['hooked'].merge!('keys' => %w[rule raw_field ial], 'optional' => %w[raw_field ial],
                                    'raw' => { 'raw_field' => 'raw_field', 'ial' => 'ial' })
    inflater = described_class.from_table(table, models: models, hooks: hooks)
    expect(inflater.bindings.map(&:keys)).to contain_exactly(%i[other], %i[rule], %i[rule raw_field],
                                                             %i[rule ial], %i[rule raw_field ial])
    expect(inflater.inflate({ rule: true }) { |n| n }).to eq(model.new(style: '', ial: nil))
    expect(inflater.inflate({ rule: true, raw_field: 'x', ial: '.c' }) { |n| n })
      .to eq(model.new(style: 'X', ial: '.c'))
  end

  it 'assigns raw captures without inflating them' do
    raw_hook = ->(attrs) { { style: attrs[:raw_field] } }
    table['rules']['hooked']['via'] = 'pass'
    table['hooks']['pass'] = 'Hooks#pass'
    subtree = { rule: true, raw_field: 'inner' } # would match the binding if inflated
    result = described_class.from_table(table, models: models, hooks: { 'pass' => raw_hook })
                            .inflate({ rule: true, raw_field: subtree }) { |n| n }
    expect(result.style).to eq(subtree)
  end

  it 'filters grouped rules with the groups argument, keeping untagged rules' do
    table['rules']['plain']['group'] = 'block'
    all = described_class.from_table(table, models: models, hooks: hooks)
    expect(all.bindings.map(&:keys)).to contain_exactly(%i[rule raw_field], %i[other])
    block = described_class.from_table(table, models: models, hooks: hooks, groups: ['block'])
    expect(block.bindings.map(&:keys)).to contain_exactly(%i[rule raw_field], %i[other])
    inline = described_class.from_table(table, models: models, hooks: hooks, groups: ['inline'])
    expect(inline.bindings.map(&:keys)).to contain_exactly(%i[rule raw_field])
  end

  it 'rejects a rule naming a hook the table does not declare' do
    table['hooks'].clear
    expect { described_class.from_table(table, models: models, hooks: hooks) }
      .to raise_error(ArgumentError, /undeclared hook/)
  end

  it 'rejects a via rule when no hook registry is provided' do
    expect { described_class.from_table(table, models: models) }
      .to raise_error(ArgumentError, /not provided/)
  end

  it 'rejects a registry that cannot resolve a declared hook' do
    expect { described_class.from_table(table, models: models, hooks: {}) }
      .to raise_error(ArgumentError, /not provided/)
  end

  it 'reads v1.1 tables from a YAML sidecar file and keeps artifact tables verbatim' do
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'table.yml')
      File.write(path, <<~YAML)
        version: '1.1'
        hooks:
          decorate: Hooks#decorate
        rules:
          hooked:
            keys: [rule, raw_field]
            model: M
            raw:
              raw_field: raw_field
            via: decorate
      YAML
      loaded = described_class.load_table(path)
      expect(loaded['version']).to eq('1.1')
      expect(loaded['rules']['hooked']['keys']).to eq(%w[rule raw_field])
      result = described_class.from_table(loaded, models: models, hooks: hooks)
                              .inflate({ rule: true, raw_field: 'leaf' }) { |n| n }
      expect(result).to eq(model.new(style: 'LEAF'))
    end
  end

  it 'rejects a sidecar rule with an unknown field or an undeclared hook' do
    bad_field = { 'version' => '1.1', 'rules' => { 'r' => { 'keys' => ['k'], 'model' => 'M', 'shapes' => {} } } }
    expect { described_class.validate_table(bad_field) }.to raise_error(ArgumentError, /unknown field/)
    bad_hook = { 'version' => '1.1', 'rules' => { 'r' => { 'keys' => ['k'], 'model' => 'M', 'via' => 'nope' } } }
    expect { described_class.validate_table(bad_hook) }.to raise_error(ArgumentError, /undeclared hook/)
    no_keys = { 'version' => '1.1', 'rules' => { 'r' => { 'model' => 'M' } } }
    expect { described_class.validate_table(no_keys) }.to raise_error(ArgumentError, /keys/)
  end
end

RSpec.describe Ceradoc::BindingInflater, '.from_table with verb mappings (a 1.2 table)' do
  let(:model) { Struct.new(:path, :name, :content, keyword_init: true) }
  let(:models) { ->(name) { { 'M' => model }.fetch(name) } }
  let(:hooks) { { 'decorate' => ->(attrs) { attrs.merge(content: 'decorated') } } }

  def table_for(via, rule = {})
    { 'version' => '1.2',
      'hooks' => { 'decorate' => 'Hooks#decorate' },
      'rules' => { 'r' => { 'keys' => %w[link], 'model' => 'M', 'children' => { 'link' => 'link' },
                            'via' => via }.merge(rule) } }
  end

  def inflate(via, node, rule = {})
    described_class.from_table(table_for(via, rule), models: models, hooks: hooks)
                   .inflate(node) { |n| n }
  end

  it 'unwrap passes the sole child capture through as the result' do
    inner = { wrapped: true }
    expect(inflate({ 'verb' => 'unwrap' }, { link: inner }, 'model' => nil)).to equal(inner)
  end

  it 'unwrap rejects an ambiguous node with several captures' do
    rule = { 'keys' => %w[link other], 'children' => { 'link' => 'link', 'other' => 'other' } }
    expect { inflate({ 'verb' => 'unwrap' }, { link: 1, other: 2 }, rule) }
      .to raise_error(ArgumentError, /needs `key`/)
  end

  it 'flatten merges the child hash entries up into the attributes' do
    expect(inflate({ 'verb' => 'flatten' }, { link: { path: 'a.adoc', name: 'n' } }))
      .to eq(model.new(path: 'a.adoc', name: 'n', content: nil))
  end

  it 'promote copies fields out of a named source capture through converters' do
    via = { 'verb' => 'promote', 'source' => 'link',
            'attrs' => { 'path' => { 'as' => 'string' }, 'name' => { 'key' => 'text', 'as' => 'string_or_nil' } } }
    rule = { 'raw' => { 'link' => 'link' } }
    node = { link: { path: 'a.png', text: 'label' } }
    expect(inflate(via, node, rule)).to eq(model.new(path: 'a.png', name: 'label', content: nil))
  end

  it 'promote without a source reads the node captures, joins and strips them' do
    via = { 'verb' => 'promote', 'attrs' => { 'content' => { 'key' => 'parts', 'as' => 'joined', 'strip' => true } } }
    rule = { 'keys' => %w[parts], 'defaults' => { 'path' => 'fallback' }, 'raw' => { 'parts' => 'parts' } }
    expect(inflate(via, { parts: [' a ', 'b'] }, rule))
      .to eq(model.new(path: 'fallback', name: nil, content: 'a b'))
  end

  it 'promote wraps a present field and falls back to its default when absent' do
    via = { 'verb' => 'promote',
            'attrs' => { 'name' => { 'key' => 'text', 'as' => 'string', 'wrap' => true, 'default' => [] } } }
    rule = { 'keys' => %w[text], 'optional' => %w[text], 'raw' => { 'text' => 'text' }, 'defaults' => { 'path' => 'p' } }
    expect(inflate(via, { text: 'x' }, rule)).to eq(model.new(path: 'p', name: ['x'], content: nil))
    expect(inflate(via, {}, rule)).to eq(model.new(path: 'p', name: [], content: nil))
  end

  it 'string makes the capture the bare result for model-less rules' do
    rule = { 'model' => nil, 'captures' => { 'text' => 'link' } }
    expect(inflate({ 'verb' => 'string', 'capture' => 'text' }, { link: 'raw' }, rule)).to eq('raw')
  end

  it 'applies a declared then hook to the verb result' do
    via = { 'verb' => 'flatten', 'then' => 'decorate' }
    expect(inflate(via, { link: { path: 'p' } })).to eq(model.new(path: 'p', name: nil, content: 'decorated'))
  end

  it 'rejects unknown verbs, unknown config, missing config and non-1.2 tables' do
    expect { described_class.validate_table(table_for({ 'verb' => 'explode' })) }
      .to raise_error(ArgumentError, /unknown verb/)
    expect { described_class.validate_table(table_for({ 'verb' => 'unwrap', 'keys' => [] })) }
      .to raise_error(ArgumentError, /unknown config/)
    expect { described_class.validate_table(table_for({ 'verb' => 'string' })) }
      .to raise_error(ArgumentError, /needs `capture`/)
    expect { described_class.validate_table(table_for({ 'verb' => 'promote', 'attrs' => 'nope' })) }
      .to raise_error(ArgumentError, /must be a mapping/)
    bad_spec = table_for({ 'verb' => 'promote', 'attrs' => { 'path' => { 'as' => 'joined', 'twice' => true } } })
    expect { described_class.validate_table(bad_spec) }.to raise_error(ArgumentError, /invalid spec/)
    old = table_for({ 'verb' => 'unwrap' }).merge('version' => '1.1')
    expect { described_class.validate_table(old) }.to raise_error(ArgumentError, /version '1.2'/)
    hooked = table_for({ 'verb' => 'flatten', 'then' => 'ghost' })
    expect { described_class.validate_table(hooked) }.to raise_error(ArgumentError, /undeclared hook/)
  end
end
