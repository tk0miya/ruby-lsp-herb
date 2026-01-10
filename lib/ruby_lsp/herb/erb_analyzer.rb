# frozen_string_literal: true

require "herb"

module RubyLsp
  module Herb
    # Analyzer class for ERB templates.
    # Parses ERB source and runs both Herb Lint and RuboCop Lint.
    class ErbAnalyzer
      attr_reader :uri #: URI::Generic?
      attr_reader :source #: String

      # @rbs uri: URI::Generic?
      # @rbs source: String
      def initialize(uri, source) #: void
        @uri = uri
        @source = source
      end

      def analyze #: ::Herb::ParseResult # rubocop:disable Metrics/AbcSize
        ::Herb.parse(source).tap do |parse_result|
          next unless parse_result.errors.empty?

          # Herb Lint: ERB tag formatting rules
          visitor = MyVisitor.new
          parse_result.visit(visitor)
          parse_result.warnings.concat(visitor.herb_warnings)

          # RuboCop Lint: Ruby code style and lint rules
          next unless uri

          result = RuboCopRunner.instance.run(uri, source)
          parse_result.errors.concat(result.herb_errors)
          parse_result.warnings.concat(result.herb_warnings)
        end
      end

      def to_prism_parse_result #: Prism::ParseResult
        herb_parse_result = analyze
        prism_source = build_prism_source(herb_parse_result.source)

        errors = herb_parse_result.errors.map do |error|
          Prism::ParseError.new(:error, error.message, convert_location(prism_source, error.location), :error)
        end

        warnings = herb_parse_result.warnings.map do |warning|
          Prism::ParseWarning.new(:warning, warning.message, convert_location(prism_source, warning.location), :warning)
        end

        value = herb_parse_result.value #: untyped
        Prism::ParseResult.new(value, [], [], nil, errors, warnings, prism_source)
      end

      private

      # @rbs source: String
      def build_prism_source(source) #: Prism::Source
        offsets = source.lines.inject([0]) { |offsets, line| offsets << (offsets.last + line.bytesize) }
        Prism::Source.for(source, 1, offsets)
      end

      # @rbs prism_source: Prism::Source
      # @rbs location: ::Herb::Location
      def convert_location(prism_source, location) #: Prism::Location
        from = prism_source.offsets[location.start.line - 1] + location.start.column
        to = prism_source.offsets[location.end.line - 1] + location.end.column
        Prism::Location.new(prism_source, from, to - from)
      end
    end
  end
end
