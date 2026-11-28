# frozen_string_literal: true

module Ceradoc
  module AsciiDoc
    module Bindings
      # Hooks for the text, block, table, section and attribute rules: the
      # genuinely semantic residue (ceradoc#386) — the shapes live as
      # verbs in the bindings table.
      module StructureHooks
        module_function

        # Generic delimited block: the delimiter picks the model class
        # (BlockTypeClassifier); capture order is kept for the serializer.
        def block(attributes)
          raw = attributes.fetch(:block)
          attribute_list = Transformer::AttributeListNormalizer.coerce(raw[:attribute_list])
          delimiter = raw[:delimiter].to_s
          opts = { id: raw[:id], title: raw[:title], delimiter_len: delimiter.size, lines: raw[:lines],
                   ordering: raw.keys.select { |key| %i[id title attribute_list].include?(key) } }
          # Markdown fences carry the language tag inline (```ruby).
          opts[:lang] = raw[:language].to_s if raw.key?(:language) && !raw[:language].nil?
          Transformer::BlockTypeClassifier.classify(delimiter, opts, attribute_list)
        end

        # Admonition type is canonicalised to uppercase so round-trips
        # through HTML/Markdown/DocBook share one key.
        def admonition(attributes)
          content = attributes.fetch(:content)
          { content: content.is_a?(Array) && content.length == 1 ? content.first : content,
            type: Transform::ElementTransformers::AdmonitionStyles.canonicalize(attributes.fetch(:type).to_s) }
        end

        def block_image(attributes)
          raw = attributes.fetch(:block_image)
          promoted, residual = Model::Image::AttributeExtractor.call(
            Transformer::AttributeListNormalizer.coerce(raw[:attribute_list_macro]), Model::Image::BlockImage
          )
          { title: raw[:title], id: raw[:id], src: raw[:path], attributes: residual, line_break: "\n", **promoted }
        end

        def table_cell(attributes)
          Transformer.build_table_cell(attributes.fetch(:format), attributes.fetch(:text))
        end

        # `table:` wrapper: an already-built Table passes through.
        def table(attributes)
          raw = attributes.fetch(:table)
          return raw unless raw.is_a?(Hash)

          attrs = Transformer::AttributeListNormalizer.coerce(raw[:attribute_list])
          opts = { rows: Transformer.regroup_table_rows(raw[:rows], attrs), attrs: }
          opts[:id] = raw[:id].to_s if raw[:id]
          title = raw[:title]&.to_s
          opts[:title] = title unless title.nil? || title.empty?
          Model::Table.new(**opts)
        end

        def title(attributes)
          { content: attributes.fetch(:text), level_int: attributes.fetch(:level).size - 1,
            line_break: attributes.fetch(:line_break) }
        end

        # `section:` wrapper: an already-built Section passes through; a
        # Title that carries an id lends it to a section without one.
        def section(attributes)
          raw = attributes.fetch(:section)
          return raw unless raw.is_a?(Hash)

          title = raw[:title]
          id = raw[:id]
          id = title.id if title.is_a?(Model::Title) && title.id && !id
          Model::Section.new(title:, id:, attribute_list: Transformer::AttributeListNormalizer.coerce(raw[:attribute_list]),
                             contents: raw[:contents] || [], sections: raw[:sections])
        end

        def document(attributes)
          raw = attributes.fetch(:document)
          Model::Document.from_ast(raw.is_a?(Array) ? raw : [raw])
        end

        # An empty comment (`//` alone) captures no inner hash, only the bare
        # `//` slice; the frozen legacy rule matched hash captures only, so
        # that node stayed raw and the document dropped it. Keep that.
        def comment_line(attributes)
          raw = attributes.fetch(:comment_line)
          return attributes unless raw.is_a?(Hash)

          Model::CommentLine.new(text: raw[:comment_text], line_break: raw[:line_break])
        end

        # An attribute list: `{positional: value}` entries stay raw here (the
        # slice keeps the source line the list is stamped with), named
        # entries are already Attributes.
        def attribute_list(attributes)
          list = Model::AttributeList.new
          Array(attributes.fetch(:attribute_array)).each do |item|
            case item
            when Hash then list.add_positional(item[:positional].to_s) if item.key?(:positional)
            when String, Parsanol::Slice then list.add_positional(item.to_s)
            when Model::Attribute then list.add_named(item.key, item.value)
            end
          end
          list
        end
      end
    end
  end
end
