# frozen_string_literal: true

module RuboCop
  module Herb
    # Transforms ERB comment nodes into Ruby comment format.
    # Returns the position and content for the transformation.
    class ERBCommentTransformer
      Result = Data.define(
        :position, #: Integer
        :content #: String
      )

      attr_reader :node #: untyped
      attr_reader :following_nodes #: Array[untyped]

      # @rbs node: untyped
      # @rbs following_nodes: Array[untyped]
      def self.call(node, following_nodes) #: Result?
        new(node, following_nodes).call
      end

      # @rbs node: untyped
      # @rbs following_nodes: Array[untyped]
      def initialize(node, following_nodes) #: void
        @node = node
        @following_nodes = following_nodes
      end

      def call #: Result?
        return nil if followed_by_code?

        ruby_comment = build_ruby_comment
        return nil unless ruby_comment

        Result.new(position:, content: "  ##{ruby_comment}")
      end

      private

      def position #: Integer
        node.tag_opening.range.from
      end

      def build_ruby_comment #: String?
        lines = node.content.value.split("\n", -1)
        target_column = node.location.start.column + 2

        lines.map.with_index do |line, idx|
          next line if idx.zero?

          case line
          when /\A {#{target_column}}/
            line[target_column] = "#"
          when /\A /
            line[0] = "#"
          else
            return nil
          end
          line
        end.join("\n")
      end

      def followed_by_code? #: bool
        following_nodes
          .take_while { |n| n.location.start.line == node.location.end.line }
          .any? { |n| !comment_node?(n) }
      end

      # @rbs node: untyped
      def comment_node?(node) #: bool
        return false unless node.respond_to?(:tag_opening)

        node.tag_opening.value == "<%#"
      end
    end
  end
end
