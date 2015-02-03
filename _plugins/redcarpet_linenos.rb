module Jekyll
  module Converters
    class Markdown
      class RedcarpetParser
        module WithPygments
          include CommonMethods
          def block_code(code, lang)
            Jekyll::Deprecator.gracefully_require("pygments")
            lang,options = lang && lang.split("|",2) || ["text",""]
            linenos = !(options && options.include?("nolines"))
            lang = lang && lang.split.first || "text"
            add_code_tags(
              Pygments.highlight(code, :lexer => lang, :options => { :encoding => 'utf-8', :linenos=> linenos}),
              lang
            )
          end
        end
      end
    end
  end
end
