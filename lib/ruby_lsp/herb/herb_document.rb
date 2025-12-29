# frozen_string_literal: true

require "ruby_lsp/erb_document"
require "herb"

module RubyLsp
  module Herb
    # @rbs generic T
    class HerbDocument < RubyLsp::ERBDocument #[T]
      attr_reader :parse_result #: ::Herb::ParseResult

      def parse! #: void # rubocop:disable Naming/PredicateMethod
        return false unless @needs_parsing

        @needs_parsing = false
        @parse_result = ::Herb.parse(source)
        @parse_result.define_singleton_method(:code_units_cache) { |_encoding| nil }
        @parse_result.define_singleton_method(:failure?) { warnings.any? || errors.any? }
        true
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
