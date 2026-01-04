# frozen_string_literal: true

require "lint_roller"
require_relative "configuration"

module RuboCop
  module Herb
    # LintRoller plugin for RuboCop integration.
    # This plugin registers the RubyExtractor with RuboCop::Runner.ruby_extractors
    # to enable linting of Ruby code embedded in ERB templates.
    class Plugin < LintRoller::Plugin
      # @rbs config: Hash[String, untyped]
      def initialize(config = {}) #: void
        super
        Configuration.setup(config)
      end

      def about #: LintRoller::About
        LintRoller::About.new(
          name: "rubocop-herb",
          version: RubyLsp::Herb::VERSION,
          homepage: "https://github.com/tk0miya/ruby-lsp-herb",
          description: "RuboCop plugin for ERB templates using Herb parser."
        )
      end

      # @rbs context: LintRoller::Context
      def supported?(context) #: bool
        context.engine == :rubocop
      end

      # @rbs context: LintRoller::Context
      def rules(context) #: LintRoller::Rules # rubocop:disable Lint/UnusedMethodArgument
        RuboCop::Runner.ruby_extractors.unshift(RubyExtractor)

        LintRoller::Rules.new(
          type: :object,
          config_format: :rubocop,
          value: Configuration.to_rubocop_config
        )
      end
    end
  end
end
