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
      # Result object that holds RuboCop offenses.
      class Result
        attr_reader :offenses #: Array[RuboCop::Cop::Offense]

        # @rbs offenses: Array[RuboCop::Cop::Offense]
        def initialize(offenses) #: void
          @offenses = offenses
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
        begin
          config_file.write(YAML.dump(::RuboCop::Herb::Configuration.to_rubocop_config))
          config_file.close

          ::RuboCop::ConfigStore.new.tap do |store|
            store.options_config = config_file.path
          end
        ensure
          config_file.unlink
        end
      end
    end
  end
end
