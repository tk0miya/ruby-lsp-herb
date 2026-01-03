# frozen_string_literal: true

module RuboCop
  module Herb
    # Builds placeholder content for empty do blocks to prevent Lint/EmptyBlock warnings.
    # Returns the position and content of the placeholder, or nil if not needed.
    class BlockPlaceholder
      LF = 10 #: Integer

      Result = Data.define(
        :position, #: Integer
        :content #: Array[Integer]
      )

      attr_reader :block_node #: ::Herb::AST::ERBBlockNode
      attr_reader :end_node #: ::Herb::AST::ERBEndNode
      attr_reader :result_bytes #: Array[Integer]

      # @rbs block_node: ::Herb::AST::ERBBlockNode
      # @rbs end_node: ::Herb::AST::ERBEndNode
      # @rbs result_bytes: Array[Integer]
      def self.build(block_node, end_node, result_bytes) #: Result?
        new(block_node, end_node, result_bytes).build
      end

      # @rbs block_node: ::Herb::AST::ERBBlockNode
      # @rbs end_node: ::Herb::AST::ERBEndNode
      # @rbs result_bytes: Array[Integer]
      def initialize(block_node, end_node, result_bytes) #: void
        @block_node = block_node
        @end_node = end_node
        @result_bytes = result_bytes
      end

      def build #: Result?
        placeholder_length = calculate_placeholder_length
        return nil if placeholder_length.negative?

        Result.new(position: start_pos + offset, content: generate_placeholder(placeholder_length))
      end

      private

      def start_pos #: Integer
        block_node.tag_closing.range.to
      end

      def end_pos #: Integer
        end_node.tag_opening.range.from
      end

      def source_bytes #: Array[Integer]
        bytes = result_bytes[start_pos...end_pos]
        raise "source_bytes out of bounds" unless bytes

        bytes
      end

      def offset #: Integer
        first_newline_pos = source_bytes.index(LF)
        if first_newline_pos
          first_newline_pos + 1
        else
          0
        end
      end

      def calculate_placeholder_length #: Integer
        bytes = source_bytes[offset...]
        raise "calculate_placeholder_length out of bounds" unless bytes

        available_space = bytes.index(LF) || bytes.length
        available_space - 3
      end

      # @rbs length: Integer
      def generate_placeholder(length) #: Array[Integer]
        "'#{" " * length}';".bytes
      end
    end
  end
end
