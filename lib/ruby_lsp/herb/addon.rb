# frozen_string_literal: true

require "ruby_lsp/addon"
require_relative "../herb"

module RubyLsp
  module Herb
    class Addon < ::RubyLsp::Addon
      attr_reader :global_state #: GlobalState
      attr_reader :logger #: Logger

      # @rbs global_state: GlobalState
      # @rbs message_queue: Thread::Queue
      def activate(global_state, message_queue) #: void
        @global_state = global_state
        @logger = Logger.new(message_queue)

        logger.info("#{name} v#{version} activated")
      end

      def deactivate #: void
      end

      def name #: String
        "Ruby LSP Herb"
      end

      def version #: String
        RubyLsp::Herb::VERSION
      end
    end
  end
end
