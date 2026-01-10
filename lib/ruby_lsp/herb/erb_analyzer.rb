# frozen_string_literal: true

require "herb"

module RubyLsp
  module Herb
    # Analyzer class for ERB templates.
    # Parses ERB source and runs both Herb Lint and RuboCop Lint.
    class ErbAnalyzer
      attr_reader :uri #: URI::Generic?
      attr_reader :source #: String
      attr_reader :herb_parse_result #: ::Herb::ParseResult?
      attr_reader :herb_warnings #: Array[::Herb::Warnings::Warning]
      attr_reader :rubocop_offenses #: Array[RuboCop::Cop::Offense]

      # @rbs uri: URI::Generic?
      # @rbs source: String
      def initialize(uri, source) #: void
        @uri = uri
        @source = source
        @herb_parse_result = nil
        @herb_warnings = []
        @rubocop_offenses = []
      end

      def analyze #: void # rubocop:disable Metrics/AbcSize
        @herb_parse_result = ::Herb.parse(source)
        return unless herb_parse_result
        return if herb_parse_result.errors.any?

        # Herb Lint: ERB tag formatting rules
        visitor = MyVisitor.new
        herb_parse_result.visit(visitor)
        herb_warnings.concat(visitor.herb_warnings)

        # RuboCop Lint: Ruby code style and lint rules
        return unless uri

        result = RuboCopRunner.instance.run(uri, source)
        rubocop_offenses.concat(result.offenses)
      end

      def to_prism_parse_result #: Prism::ParseResult # rubocop:disable Metrics/AbcSize
        raise "Must call analyze before to_prism_parse_result" unless herb_parse_result

        prism_source = build_prism_source(herb_parse_result.source)

        # Herb parser errors
        errors = herb_parse_result.errors.map do |error|
          location = convert_herb_location(prism_source, error.location)
          Prism::ParseError.new(:error, error.message, location, :error)
        end

        # Herb parser warnings
        warnings = herb_parse_result.warnings.map do |warning|
          location = convert_herb_location(prism_source, warning.location)
          Prism::ParseWarning.new(:warning, warning.message, location, :warning)
        end

        # Herb Lint warnings
        herb_warnings.each do |warning|
          location = convert_herb_location(prism_source, warning.location)
          warnings << Prism::ParseWarning.new(:warning, warning.message, location, :warning)
        end

        # RuboCop offenses (preserving severity)
        rubocop_offenses.each do |offense|
          level = rubocop_severity_to_prism_level(offense.severity.name)
          location = convert_offense_location(prism_source, offense)
          message = "[#{offense.cop_name}] #{offense.message}"
          if %i[error fatal].include?(offense.severity.name)
            errors << Prism::ParseError.new(level, message, location, level)
          else
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
