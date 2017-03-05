# -*- coding: utf-8 -*- #

# Taken from /usr/local/lib/ruby/gems/2.3.0/gems/rouge-1.11.1/lib/rouge/formatters/html.rb

# stdlib
require 'cgi'
require 'rouge'

module Rouge
  module Formatters
    # Transforms a token stream into HTML output.
    class HTML < Formatter
      tag 'html'

      # @option opts [String] :css_class ('highlight')
      # @option opts [true/false] :line_numbers (false)
      # @option opts [Rouge::CSSTheme] :inline_theme (nil)
      # @option opts [true/false] :wrap (true)
      #
      # Initialize with options.
      #
      # If `:inline_theme` is given, then instead of rendering the
      # tokens as <span> tags with CSS classes, the styles according to
      # the given theme will be inlined in "style" attributes.  This is
      # useful for formats in which stylesheets are not available.
      #
      # Content will be wrapped in a tag (`div` if tableized, `pre` if
      # not) with the given `:css_class` unless `:wrap` is set to `false`.
      def initialize(opts={})
        @css_class = opts.fetch(:css_class, 'highlight')
        @css_class = " class=#{@css_class.inspect}" if @css_class

        @format_style = opts.fetch(:format_style, 'table')
        @line_numbers = opts.fetch(:line_numbers, false)
        @start_line = opts.fetch(:start_line, 1)
        @inline_theme = opts.fetch(:inline_theme, nil)
        @inline_theme = Theme.find(@inline_theme).new if @inline_theme.is_a? String

        @wrap = opts.fetch(:wrap, true)
      end

      # @yield the html output.
      def stream(tokens, &b)
        if @line_numbers
          if @format_style == "div"
            stream_divized(tokens, &b)
          else
            stream_tableized(tokens, &b)
          end
        else
          stream_lightformat(tokens, &b)
        end
      end

    private
      def stream_lightformat(tokens, &b)
        yield "<pre#@css_class><code>" if @wrap
        tokens.each{ |tok, val| span(tok, val, &b) }
        yield "</code></pre>\n" if @wrap
      end

      def stream_tableized(tokens, &b)
        stream_formatted(tokens, 'table', &b)
      end

      def stream_divized(tokens, &b)
        stream_formatted(tokens, 'div', &b)
      end

      def stream_formatted(tokens, style = 'table', &b)
        num_lines = 0
        last_val = ''
        formatted = ''

        tokens.each do |tok, val|
          last_val = val
          num_lines += val.scan(/\n/).size
          span(tok, val) { |str| formatted << str }
        end

        # add an extra line for non-newline-terminated strings
        if last_val[-1] != "\n"
          num_lines += 1
          span(Token::Tokens::Text::Whitespace, "\n") { |str| formatted << str }
        end

        # generate a string of newline-separated line numbers for the gutter>
        numbers = %<<pre class="lineno">#{(@start_line..num_lines+@start_line-1)
          .to_a.join("\n")}</pre>>

        yield "<div#@css_class>" if @wrap
        
        if style == "div"
          yield '<div style="display: table; border-spacing: 0"><div style="display: table-row">'
        else
          yield '<table style="border-spacing: 0"><tbody><tr>'
        end

        # the "gl" class applies the style for Generic.Lineno
        if style == "div"
          yield '<div class="gutter gl" style="display: table-cell; text-align: right">'
        else
          yield '<td class="gutter gl" style="text-align: right">'
        end
        yield numbers
        if style == "div"
          yield '</div>'
        else
          yield '</td>'
        end

        if style == "div"
          yield '<div style="display: table-cell;" class="code">'
        else
          yield '<td class="code">'
        end
        yield '<pre>'
        yield formatted
        yield '</pre>'
        if style == "div"
          yield '</div>'
        else
          yield '</td>'
        end

        if style == "div"
          yield "</div></div>\n"
        else
          yield "</tr></tbody></table>\n"
        end
        yield "</div>\n" if @wrap
      end

      # TABLE_FOR_ESCAPE_HTML = {
      #   '&' => '&amp;',
      #   '<' => '&lt;',
      #   '>' => '&gt;',
      # }

    #   def span(tok, val)
    #     val = val.gsub(/[&<>]/, TABLE_FOR_ESCAPE_HTML)
    #     shortname = tok.shortname or raise "unknown token: #{tok.inspect} for #{val.inspect}"
    # 
    #     if shortname.empty?
    #       yield val
    #     else
    #       if @inline_theme
    #         rules = @inline_theme.style_for(tok).rendered_rules
    # 
    #         yield "<span style=\"#{rules.to_a.join(';')}\">#{val}</span>"
    #       else
    #         yield "<span class=\"#{shortname}\">#{val}</span>"
    #       end
    #     end
    #   end
    end
  end
end
