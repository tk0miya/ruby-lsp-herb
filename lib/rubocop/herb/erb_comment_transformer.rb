# frozen_string_literal: true

module RuboCop
  module Herb
    # Transforms ERB comment content to Ruby comment format.
    # Returns the transformed content or nil if the comment cannot be transformed.
    module ERBCommentTransformer
      class << self
        # @rbs node: untyped
        def call(node) #: String?
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
      end
    end
  end
end
