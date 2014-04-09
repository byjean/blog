# _plugins/redcarpet_rouge.rb
require 'redcarpet'

module Jekyll
  module Converters
    class Markdown
      class RedcarpetParser
        module CommonMethods
          def add_code_tags(code, lang)
            code = code.to_s
            code = code.gsub(/<pre>/, "<pre><code class=\"#{lang} language-#{lang}\" data-lang=\"#{lang}\">")
            code = code.gsub(/<\/pre>/,"</code></pre>")
          end
        end
        module WithPygments
          include CommonMethods
          def block_code(code, lang)
            require 'pygments'
            lang = lang && lang.split.first || "text"
            output = add_code_tags(
              Pygments.highlight(code, :lexer => lang, :options => { :encoding => 'utf-8', :linenos => 'table' }),
              lang
            )
            "<figure class='code'><div class='highlight'>"+output+"</div></figure>"
          end
        end
      end
    end
  end
end
