# frozen_string_literal: true

require "ruby_lsp/document"
require "ruby_lsp/erb_document"

require "active_support/all"
require "herb"

module RubyLsp
  module Herb
    # @rbs generic T
    class HerbDocument < RubyLsp::ERBDocument #[T]
      attr_reader :parse_result #: ::Prism::ParseResult

      def parse! #: void # rubocop:disable Naming/PredicateMethod
        return false unless @needs_parsing

        @needs_parsing = false
        analyzer = ErbAnalyzer.new(uri, source)
        analyzer.analyze
        @parse_result = analyzer.to_prism_parse_result
        true
      end

      def ast #: Prism::ProgramNode
        # Return empty ProgramNode because Ruby LSP expects Prism AST,
        # but HerbDocument uses Herb AST which is not compatible with Prism.
        Prism.parse("").value
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
