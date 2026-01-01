# frozen_string_literal: true

require "lint_roller"

module RuboCop
  module Herb
    # LintRoller plugin for RuboCop integration.
    # This plugin registers the RubyExtractor with RuboCop::Runner.ruby_extractors
    # to enable linting of Ruby code embedded in ERB templates.
    class Plugin < LintRoller::Plugin
      CONFIG_PATH = File.expand_path("../../../config/rubocop-herb/default.yml", __dir__.to_s) #: String

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
          type: :path,
          config_format: :rubocop,
          value: CONFIG_PATH
        )
      end
    end
  end
end
