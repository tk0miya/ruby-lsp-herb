# frozen_string_literal: true

module RubyLsp
  module Herb
    class Logger
      attr_reader :message_queue #: Thread::Queue

      # @rbs message_queue: Thread::Queue
      def initialize(message_queue) #: void
        @message_queue = message_queue
      end

      # @rbs message: String
      def info(message) #: void
        message_queue << Notification.window_log_message("herb: #{message}")
      end
    end
  end
end
