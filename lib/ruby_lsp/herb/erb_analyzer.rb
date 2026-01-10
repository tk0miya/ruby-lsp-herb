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

      def to_prism_parse_result #: Prism::ParseResult # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        herb_parse_result = ::Herb.parse(source)
        prism_source = build_prism_source(herb_parse_result.source)

        # Herb parser errors
        errors = herb_parse_result.errors.map do |error|
          loc = convert_herb_location(prism_source, error.location)
          Prism::ParseError.new(:error, error.message, loc, :error)
        end

        # Herb parser warnings
        warnings = herb_parse_result.warnings.map do |warning|
          loc = convert_herb_location(prism_source, warning.location)
          Prism::ParseWarning.new(:warning, warning.message, loc, :warning)
        end

        if errors.any?
          value = herb_parse_result.value #: untyped
          return Prism::ParseResult.new(value, [], [], nil, errors, warnings, prism_source)
        end

        # Herb Lint: ERB tag formatting rules
        visitor = MyVisitor.new
        herb_parse_result.visit(visitor)
        visitor.herb_warnings.each do |warning|
          loc = convert_herb_location(prism_source, warning.location)
          warnings << Prism::ParseWarning.new(:warning, warning.message, loc, :warning)
        end

        # RuboCop Lint: Ruby code style and lint rules (preserving severity)
        if uri
          result = RuboCopRunner.instance.run(uri, source)
          result.offenses.each do |offense|
            level = rubocop_severity_to_prism_level(offense.severity.name)
            location = convert_offense_location(prism_source, offense)
            message = "[#{offense.cop_name}] #{offense.message}"
            warnings << Prism::ParseWarning.new(level, message, location, level)
          end
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
      def convert_herb_location(prism_source, location) #: Prism::Location
        from = prism_source.offsets[location.start.line - 1] + location.start.column
        to = prism_source.offsets[location.end.line - 1] + location.end.column
        Prism::Location.new(prism_source, from, to - from)
      end

      # @rbs prism_source: Prism::Source
      # @rbs offense: RuboCop::Cop::Offense
      def convert_offense_location(prism_source, offense) #: Prism::Location
        # offense.line is 1-based, offense.column is 0-based
        from = prism_source.offsets[offense.line - 1] + offense.column
        length = offense.location.length
        Prism::Location.new(prism_source, from, length)
      end

      # @rbs severity: Symbol
      def rubocop_severity_to_prism_level(severity) #: Symbol
        case severity
        when :info then :hint
        when :refactor, :convention then :information
        when :error, :fatal then :error
        else :warning # :warning and unknown severities
        end
      end
    end
  end
end
