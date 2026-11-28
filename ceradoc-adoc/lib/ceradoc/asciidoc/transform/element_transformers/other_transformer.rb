# frozen_string_literal: true

module Ceradoc
  module AsciiDoc
    module Transform
      module ElementTransformers
        class OtherTransformer
          class << self
            def transform_term(term)
              Ceradoc::CoreModel::Term.new(
                text: term.term.to_s,
                term_type: term.type&.to_s || 'preferred',
                lang: term.lang&.to_s || 'en',
                source_line: term.source_line
              )
            end

            def transform_admonition(admonition)
              canonical = Ceradoc::AsciiDoc::Transform::ElementTransformers::AdmonitionStyles.canonicalize(admonition.type) || admonition.type.to_s
              inline = ToCoreModel.transform_inline_content(admonition.content)
              inline = [Ceradoc::CoreModel::TextContent.new(text: '')] if inline.empty?
              paragraph = Ceradoc::CoreModel::ParagraphBlock.new(
                content: ToCoreModel.extract_text_content(admonition.content),
                children: inline,
                source_line: admonition.source_line
              )
              # Single-line admonitions (`NOTE: text`) carry their content
              # in a ParagraphBlock child, matching the delimited
              # (`[NOTE]\n====\n...\n====`) path so both spellings produce
              # the same CoreModel shape (#376).
              Ceradoc::CoreModel::AnnotationBlock.new(
                annotation_type: canonical,
                content: paragraph.content,
                children: [paragraph],
                source_line: admonition.source_line
              )
            end

            def transform_image(image)
              Ceradoc::CoreModel::Image.new(**image_attributes(image))
            end

            def image_attributes(image)
              {
                src: normalize_image_src(image.src),
                alt: image.alt, title: image.title, caption: image.caption,
                width: image.width, height: image.height,
                link: image.link, role: image.role,
                inline: image.is_a?(Ceradoc::AsciiDoc::Model::Image::InlineImage),
                source_line: image.source_line
              }
            end

            def normalize_image_src(src)
              s = src.to_s
              s.start_with?(':') ? s[1..] : s
            end

            def transform_bibliography(bib)
              entries = Array(bib.entries).map do |entry|
                transform_bibliography_entry(entry)
              end

              Ceradoc::CoreModel::Bibliography.new(
                id: bib.id,
                title: bib.title.to_s,
                level: nil,
                entries: entries,
                source_line: bib.source_line
              )
            end

            def transform_bibliography_entry(entry)
              Ceradoc::CoreModel::BibliographyEntry.new(
                anchor_name: entry.anchor_name,
                document_id: entry.document_id,
                ref_text: entry.ref_text.to_s,
                source_line: entry.source_line
              )
            end
          end
        end
      end
    end
  end
end
