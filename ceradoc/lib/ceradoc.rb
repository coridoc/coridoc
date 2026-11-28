# frozen_string_literal: true

# Ceradoc - Canonical Document Model and Transformation Hub
#
# Ceradoc provides a hub-and-spoke architecture for document transformations.
# The CoreModel serves as the canonical, format-agnostic representation,
# enabling transformations between AsciiDoc, HTML, Markdown, DOCX, and more.
#
# @example Converting between formats
#   require 'ceradoc'
#   html = Ceradoc.convert("# Hello", from: :markdown, to: :html)
#
# @example Parsing and serializing
#   doc = Ceradoc.parse("# Title\n\nContent", format: :markdown)
#   html = Ceradoc.serialize(doc, to: :html)
#
# @example File-based conversion
#   doc = Ceradoc.parse_file("input.md")
#   html = Ceradoc.convert_file("input.md", to: :html)
#
# @example Manipulating documents
#   doc = Ceradoc.parse(text, format: :asciidoc)
#   html = Ceradoc.serialize(doc, to: :html)
#
# @example Building documents programmatically
#   doc = Ceradoc.build do |d|
#     d.title = "My Document"
#     d.children << Ceradoc::CoreModel::ParagraphBlock.new(content: "Hello")
#   end
#   Ceradoc.serialize(doc, to: :html)

require_relative 'ceradoc/ceradoc'

module Ceradoc
  autoload :VERSION, 'ceradoc/version'
  autoload :CLI, 'ceradoc/cli'
  autoload :Visitor, 'ceradoc/visitor'
  autoload :BindingInflater, 'ceradoc/binding_inflater'
  autoload :BindingVerbs, 'ceradoc/binding_verbs'
  autoload :LinkRewriter, 'ceradoc/link_rewriter'
  autoload :RelativePath, 'ceradoc/relative_path'
end
