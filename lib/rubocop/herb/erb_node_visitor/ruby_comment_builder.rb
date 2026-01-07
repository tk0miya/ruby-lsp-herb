# frozen_string_literal: true

module RuboCop
  module Herb
    class ErbNodeVisitor
      # Builds Ruby comment strings from ERB comment nodes.
      # Transforms multi-line ERB comments into valid Ruby comments.
      module RubyCommentBuilder
        # @rbs node: ::Herb::AST::ERBContentNode
        def build_ruby_comment(node) #: String?
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
