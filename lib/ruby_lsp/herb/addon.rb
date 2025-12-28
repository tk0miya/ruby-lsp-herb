# frozen_string_literal: true

require "ruby_lsp/addon"

module RubyLsp
  module Herb
    class Addon < ::RubyLsp::Addon
      # @rbs global_state: GlobalState
      # @rbs message_queue: Thread::Queue
      def activate(global_state, message_queue) #: void
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
