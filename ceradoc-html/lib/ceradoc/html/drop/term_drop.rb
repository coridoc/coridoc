# frozen_string_literal: true

module Ceradoc
  module Html
    module Drop
      class TermDrop < Base
        def text
          Escape.escape_html(@model.text.to_s)
        end

        def term_ref
          @model.text.to_s
        end

        def css_class
          t = @model.term_type || 'term'
          "term term-#{t}"
        end
      end

      DropFactory.register(CoreModel::Term, TermDrop)
    end
  end
end
