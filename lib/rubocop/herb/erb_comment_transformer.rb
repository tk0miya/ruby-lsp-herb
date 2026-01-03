# frozen_string_literal: true

module RuboCop
  module Herb
    # Transforms ERB comment content to Ruby comment format.
    # Returns the transformed content or nil if the comment cannot be transformed.
    module ERBCommentTransformer
      class << self
        # @rbs node: untyped
        # @rbs following_nodes: Array[untyped]
        def call(node, following_nodes) #: String?
          return nil if followed_by_code?(following_nodes)

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

        private

        # @rbs following_nodes: Array[untyped]
        def followed_by_code?(following_nodes) #: bool
          following_nodes.any? { |node| !comment_node?(node) }
        end

        # @rbs node: untyped
        def comment_node?(node) #: bool
          return false unless node.respond_to?(:tag_opening)

          node.tag_opening.value == "<%#"
        end
      end
    end
  end
end
