# frozen_string_literal: true

require "ruby_lsp/erb_document"

require "active_support/all"
require "herb"

module RubyLsp
  module Herb
    # @rbs generic T
    class HerbDocument < RubyLsp::ERBDocument #[T]
      attr_reader :parse_result #: ::Herb::ParseResult

      def parse! #: void # rubocop:disable Naming/PredicateMethod
        return false unless @needs_parsing

        @needs_parsing = false
        @parse_result = convert_parse_result(parse_html_erb(source))
        true
      end

      def parse_html_erb(source) #: void # rubocop:disable Metrics/AbcSize
        ::Herb.parse(source).tap do |parse_result|
          parse_result.define_singleton_method(:code_units_cache) { |_encoding| nil }
          parse_result.define_singleton_method(:failure?) { warnings.any? || errors.any? }

          break unless parse_result.errors.empty?

          visitor = MyVisitor.new
          parse_result.visit(visitor)
          visitor.offences.each do |message, location|
            parse_result.warnings << ::Herb::Warnings::Warning.new("warning", location, message)
          end
        end
      end

      def convert_parse_result(herb_parse_result) #: Prism::ParseResult
        source = convert_source(herb_parse_result.source)
        errors = herb_parse_result.errors.map do |error|
          Prism::ParseError.new(:error, error.message, convert_location(source, error.location), :error)
        end
        warnings = herb_parse_result.warnings.map do |warning|
          Prism::ParseWarning.new(:warning, warning.message, convert_location(source, warning.location), :warning)
        end
        Prism::ParseResult.new(herb_parse_result.value, [], [], nil, errors, warnings, source)
      end

      def convert_source(source) #: Prism::Source
        offsets = source.lines.inject([0]) { |offsets, line| offsets << (offsets.last + line.bytesize) }
        offsets.pop
        Prism::Source.for(source, 1, offsets)
      end

      def convert_location(source, location) #: Prism::Location # rubocop:disable Metrics/AbcSize
        from = source.offsets[location.start.line - 1] + location.start.column
        to = source.offsets[location.end.line - 1] + location.end.column
        Prism::Location.new(source, from, to - from)
      end

      def syntax_error? #: bool
        # Return true even if no syntax error exists in HTML+ERB document
        # to avoid linting the document by rubocop.  Ruby LSP goes linting if
        # the document has no syntax error.
        # see https://github.com/Shopify/ruby-lsp/blob/main/lib/ruby_lsp/requests/diagnostics.rb
        true
      end
    end
  end
end
