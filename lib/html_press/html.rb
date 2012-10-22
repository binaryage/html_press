module HtmlPress

  class Html

    DEFAULTS = {
      :logger => false,
      :unquoted_attributes => false,
      :drop_empty_values => false,
      :strip_crlf => false,
      :js_minifier_options => false
    }

    def initialize (options = {})
      @options = DEFAULTS.merge(options)
      if @options.keys.include? :dump_empty_values
        @options[:drop_empty_values] = @options.delete(:dump_empty_values)
        warn "dump_empty_values deprecated use drop_empty_values"
      end
      if @options[:logger] && !@options[:logger].respond_to?(:error)
        raise ArgumentError, 'Logger has no error method'
      end
    end

    def press (html)
      out = html.respond_to?(:read) ? html.read : html.dup

      @replacement_hash = 'MINIFYHTML' + Time.now.to_i.to_s

      out.gsub! "\r", ''

      # out = process_ie_conditional_comments out
      out = process_scripts out
      out = process_styles out

      out = process_html_comments out
      out = trim_lines out
      out = process_block_elements out

      out = process_whitespaces out

      out = process_attributes out
      out = fixup_void_elements out

      out.gsub! /^$\n/, '' # remove empty lines

      out = reindent out

      out
    end

    # for backward compatibility
    alias :compile :press

    protected

    def reindent (out)
      level = 0
      in_script = 0
      in_style = 0
      res = []
      out.split("\n").each do |line|
        pre_level = level

        line.gsub /<([\/]*[a-z\-:]+)([^>]*?)>/i do |m|
          if $1 == "script" then
            level += 1
            in_script += 1
          end
          in_script -= 1 if $1 == "/script"
          if $1 == "style" then
            level += 1
            in_style += 1
          end
          in_style -= 1 if $1 == "/style"

          next if m[1]=="!"
          next if m[-2]=="/"
          next if in_style > 0 or in_script > 0

          m[1]=="/" ? level -= 1 : level += 1
          level = 0 if level < 0
        end

        level < pre_level ? i = level : i = pre_level
        res << (("  " * i) + line)
      end

      res.join("\n")
    end

    def process_attributes (out)
      out.gsub /<([a-z\-:]+)([^>]*?)([\/]*?)>/i do |m|
        "<"+$1+($2.gsub(/[\n]+/, ' ').gsub(/[ ]+/, ' ').rstrip)+">"
      end
    end

    def fixup_void_elements (out)
      # http://dev.w3.org/html5/spec/syntax.html#void-elements
      out.gsub /<(area|base|br|col|command|embed|hr|img|input|keygen|link|meta|param|source|track|wbr)([^>]*?)[\/]*>/i do |m|
        "<"+$1+$2+"/>"
      end
    end

    def process_scripts (out)
      in_script = 0
      res = []
      buffer = []
      out.split("\n").each do |line|
        was_inscript = in_script
        line.gsub /<([\/]*[a-z\-:]+)([^>]*?)>/i do |m|
          if $1 == "script" then
            in_script += 1
            buffer = []
          elsif $1 == "/script"
            in_script -= 1
            if in_script == 0 then
              js = buffer.join("\n")
              js_compressed = HtmlPress.js_compressor js, @options[:js_minifier_options], @options[:cache]
              res << js_compressed
            end
          end
          m
        end

        if was_inscript > 0 and in_script > 0 then
          buffer << line
        else
          res << line
        end
      end

      res.join("\n")
    end

     def process_styles (out)
      in_script = 0
      res = []
      buffer = []
      out.split("\n").each do |line|
        was_instyle = in_script
        line.gsub /<([\/]*[a-z\-:]+)([^>]*?)>/i do |m|
          if $1 == "style" then
            in_script += 1
            buffer = []
          elsif $1 == "/style"
            in_script -= 1
            if in_script == 0 then
              css = buffer.join("\n")
              res << (HtmlPress.style_compressor css, @options[:cache])
            end
          end
        end

        if was_instyle > 0 and in_script > 0 then
          buffer << line
        else
          res << line
        end
      end

      res.join("\n")
    end

    # remove html comments (not IE conditional comments)
    def process_html_comments (out)
      out.gsub /<!--([ \t]*?)-->/, ''
    end

    # trim each line
    def trim_lines (out)
      out.gsub(/^[ \t]+|[ \t]+$/m, '')
    end

    # remove whitespaces outside of block elements
    def process_block_elements (out)
      re = '[ \t]+(<\\/?(?:area|base(?:font)?|blockquote|body' +
        '|caption|center|cite|col(?:group)?|dd|dir|div|dl|dt|fieldset|form' +
        '|frame(?:set)?|h[1-6]|head|hr|html|legend|li|link|map|menu|meta' +
        '|ol|opt(?:group|ion)|p|param|t(?:able|body|head|d|h|r|foot|itle)' +
        '|ul)\\b[^>]*>)'

      re = Regexp.new(re)
      out.gsub!(re, '\\1')

      # remove whitespaces outside of all elements
      out.gsub! />([^<]+)</ do |m|
        m.gsub(/^[ \t]+|[ \t]+$/, ' ')
      end

      out
    end

    # replace two or more whitespaces with one
    def process_whitespaces (out)
      out.gsub!(/[\r\n]+/, @options[:strip_crlf] ? ' ' : "\n")
      out.gsub!(/[ \t]+/, ' ')
      out
    end

    def log (text)
      @options[:logger].error text if @options[:logger]
    end

  end
end
