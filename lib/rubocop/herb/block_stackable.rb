# frozen_string_literal: true

module RuboCop
  module Herb
    # Provides stack-based block management for ERB node collection.
    # Manages nested blocks using a stack of Result arrays.
    module BlockStackable
      attr_reader :stack #: Array[Array[Result]]

      def init_stack #: void
        @stack = [[]]
      end

      def current_block #: Array[Result]
        stack.last or raise "current_block is nil"
      end

      def push_new_block #: void
        stack << []
      end

      def pop_block #: Array[Result]
        raise "Cannot pop root scope" if stack.size <= 1

        stack.pop or raise "pop_block is nil"
      end

      # @rbs result: Result
      def push_node(result) #: void
        current_block.push(result)
      end

      def peek_node #: Result?
        current_block.last
      end

      def pop_node #: Result?
        current_block.pop
      end
    end
  end
end
