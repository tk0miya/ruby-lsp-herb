# frozen_string_literal: true

require_relative "characters"

module RuboCop
  module Herb
    # Builds placeholder Results for empty do blocks to prevent Lint/EmptyBlock warnings.
    class PlaceholderBuilder
      include Characters

      PLACEHOLDER_CONTENT = "_ = nil;" #: String

      attr_reader :source_bytes #: Array[Integer]

      # @rbs source_bytes: Array[Integer]
      def initialize(source_bytes) #: void
        @source_bytes = source_bytes
      end

      # @rbs start_result: Result
      # @rbs end_node: ::Herb::AST::erb_nodes
      def build(start_result, end_node) #: Result?
        position = calculate_position(start_result, end_node)
        return nil unless position

        Result.new(
          position: position,
          tag_opening: "",
          tag_closing: "",
          prefix: "",
          content: PLACEHOLDER_CONTENT,
          location: start_result.location,
          node: nil
        )
      end

      private

      # @rbs start_result: Result
      # @rbs end_node: ::Herb::AST::erb_nodes
      def calculate_position(start_result, end_node) #: Integer?
        content_length = start_result.code.bytesize
        start_pos = start_result.position + content_length
        end_pos = end_node.tag_opening.range.from

        range_bytes = source_bytes[start_pos...end_pos]
        return nil unless range_bytes

        offset = calculate_offset(range_bytes)
        return nil unless offset

        start_pos + offset
      end

      # @rbs range_bytes: Array[Integer]
      def calculate_offset(range_bytes) #: Integer?
        first_newline_pos = range_bytes.index(LF)
        offset = first_newline_pos ? first_newline_pos + 1 : 0

        remaining_bytes = range_bytes[offset...]
        return nil unless remaining_bytes

        available = remaining_bytes.index(LF) || remaining_bytes.length
        return nil unless available >= PLACEHOLDER_CONTENT.bytesize

        offset
      end
    end
  end
end
