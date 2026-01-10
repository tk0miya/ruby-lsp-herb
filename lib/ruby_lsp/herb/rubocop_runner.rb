# frozen_string_literal: true

require "rubocop"
require "rubocop/lsp/stdin_runner"
require "tempfile"
require "yaml"

require_relative "../../rubocop/herb/configuration"
require_relative "../../rubocop/herb/ruby_extractor"

module RubyLsp
  module Herb
    # Runner class for executing RuboCop on ERB templates using StdinRunner.
    # Uses RuboCop::Herb::RubyExtractor to extract Ruby code from ERB.
    class RuboCopRunner
      # Result object that holds RuboCop offenses and provides Herb-compatible errors/warnings.
      class Result
        attr_reader :offenses #: Array[RuboCop::Cop::Offense]

        # @rbs offenses: Array[RuboCop::Cop::Offense]
        def initialize(offenses) #: void
          @offenses = offenses
        end

        def herb_errors #: Array[::Herb::Errors::Error]
          offenses.filter_map do |offense|
            next unless %i[error fatal].include?(offense.severity.name)

            location = convert_offense_to_herb_location(offense)
            message = "[#{offense.cop_name}] #{offense.message}"
            ::Herb::Errors::Error.new("error", location, message)
          end
        end

        def herb_warnings #: Array[::Herb::Warnings::Warning]
          offenses.filter_map do |offense|
            next if %i[error fatal].include?(offense.severity.name)

            location = convert_offense_to_herb_location(offense)
            message = "[#{offense.cop_name}] #{offense.message}"
            ::Herb::Warnings::Warning.new("warning", location, message)
          end
        end

        private

        # Convert RuboCop offense location to Herb::Location
        # @rbs offense: RuboCop::Cop::Offense
        def convert_offense_to_herb_location(offense) #: ::Herb::Location
          # offense.line is 1-based, offense.column is 0-based
          ::Herb::Location.from(
            offense.line,
            offense.column,
            offense.line,
            offense.column + offense.location.length
          )
        end
      end

      # @rbs self.@instance: RuboCopRunner

      class << self
        def instance #: RuboCopRunner
          @instance ||= new
        end
      end

      attr_reader :config_store #: RuboCop::ConfigStore
      attr_reader :runner #: RuboCop::Lsp::StdinRunner

      def initialize #: void
        ::RuboCop::Herb::Configuration.setup({})
        setup_extractor
        @config_store = build_config_store
        @runner = ::RuboCop::Lsp::StdinRunner.new(config_store)
      end

      # @rbs uri: URI::Generic
      # @rbs source: String
      def run(uri, source) #: Result
        path = uri.to_standardized_path || uri.opaque
        return Result.new([]) unless path

        options = {} #: Hash[untyped, untyped]
        runner.run(path, source, options)
        Result.new(runner.offenses)
      end

      private

      def setup_extractor #: void
        extractors = ::RuboCop::Lsp::StdinRunner.ruby_extractors
        return if extractors.include?(::RuboCop::Herb::RubyExtractor)

        extractors.unshift(::RuboCop::Herb::RubyExtractor)
      end

      def build_config_store #: untyped
        config_file = Tempfile.new([".rubocop", ".yml"], Dir.pwd)
        config_file.write(YAML.dump(::RuboCop::Herb::Configuration.to_rubocop_config))
        config_file.close

        ::RuboCop::ConfigStore.new.tap do |store|
          store.options_config = config_file.path
        end
      end
    end
  end
end
