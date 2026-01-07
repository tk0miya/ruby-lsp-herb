# frozen_string_literal: true

require "herb"

module RuboCop
  module Herb
    # Visitor class to transform ERB nodes from Herb AST
    # Collects Result objects from AST traversal
    class ErbNodeVisitor < ::Herb::Visitor
    end
  end
end

require_relative "erb_node_visitor/block_stackable"
require_relative "erb_node_visitor/placeholder_builder"
require_relative "erb_node_visitor/result"
require_relative "erb_node_visitor/ruby_comment_builder"
require_relative "erb_node_visitor/tag_openings"

module RuboCop
  module Herb
    class ErbNodeVisitor # rubocop:disable Metrics/ClassLength
      include BlockStackable
      include RubyCommentBuilder

      attr_reader :placeholder_builder #: PlaceholderBuilder

      # @rbs source_bytes: Array[Integer]
      def initialize(source_bytes) #: void
        init_stack
        @placeholder_builder = PlaceholderBuilder.new(source_bytes)
        super()
      end

      def results #: Array[Result]
        current_block
      end

      # --- Content tags (<%= and <% and <%# are all ERBContentNode) ---
      # @rbs node: ::Herb::AST::ERBContentNode
      def visit_erb_content_node(node) #: void
        if comment_tag?(node)
          push_comment_tag(node)
        elsif output_tag?(node)
          push_output_tag(node)
        else
          push_erb_tag(node)
        end
        super
      end

      # --- Block opening tags (push_new_block + push_erb_tag) ---
      # @rbs node: ::Herb::AST::ERBBlockNode
      def visit_erb_block_node(node) #: void
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBIfNode
      def visit_erb_if_node(node) #: void
        # elsif closes previous block and opens new one
        close_block(node) if elsif_node?(node)
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBUnlessNode
      def visit_erb_unless_node(node) #: void
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBCaseNode
      def visit_erb_case_node(node) #: void
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBWhileNode
      def visit_erb_while_node(node) #: void
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBUntilNode
      def visit_erb_until_node(node) #: void
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBForNode
      def visit_erb_for_node(node) #: void
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBBeginNode
      def visit_erb_begin_node(node) #: void
        push_new_block
        push_erb_tag(node)
        super
      end

      # --- Block closing tags ---
      # @rbs node: ::Herb::AST::ERBEndNode
      def visit_erb_end_node(node) #: void
        close_block(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBElseNode
      def visit_erb_else_node(node) #: void
        close_block(node)
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBWhenNode
      def visit_erb_when_node(node) #: void
        close_block(node)
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBInNode
      def visit_erb_in_node(node) #: void
        close_block(node)
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBRescueNode
      def visit_erb_rescue_node(node) #: void
        close_block(node)
        push_new_block
        push_erb_tag(node)
        super
      end

      # @rbs node: ::Herb::AST::ERBEnsureNode
      def visit_erb_ensure_node(node) #: void
        close_block(node)
        push_new_block
        push_erb_tag(node)
        super
      end

      # --- Document node (root) ---
      # @rbs node: ::Herb::AST::DocumentNode
      def visit_document_node(node) #: void
        super
        finalize!
      end

      private

      def finalize! #: void
        adjust_last_output_prefix! # Adjust last output tag's prefix (EOF case)
        filter_comments! # Filter out comments with code on same line
      end

      # @rbs node: ::Herb::AST::erb_nodes
      def output_tag?(node) #: bool
        TagOpenings.output?(node.tag_opening.value)
      end

      # @rbs node: ::Herb::AST::erb_nodes
      def comment_tag?(node) #: bool
        TagOpenings.comment?(node.tag_opening.value)
      end

      # @rbs node: ::Herb::AST::ERBIfNode
      def elsif_node?(node) #: bool
        node.content.value.lstrip.start_with?("elsif")
      end

      # @rbs node: ::Herb::AST::erb_nodes
      def push_output_tag(node) #: void
        result = Result.new(
          position: node.tag_opening.range.from,
          tag_opening: node.tag_opening.value,
          tag_closing: node.tag_closing.value,
          prefix: "_ =",
          content: build_ruby_code(node),
          location: node.location,
          node:
        )
        push_node(result)
      end

      # @rbs node: ::Herb::AST::erb_nodes
      def push_erb_tag(node) #: void
        result = Result.new(
          position: node.tag_opening.range.from,
          tag_opening: node.tag_opening.value,
          tag_closing: node.tag_closing.value,
          prefix: " " * node.tag_opening.value.size,
          content: build_ruby_code(node),
          location: node.location,
          node:
        )
        push_node(result)
      end

      # @rbs node: ::Herb::AST::ERBContentNode
      def push_comment_tag(node) #: void
        ruby_comment = build_ruby_comment(node)
        return unless ruby_comment

        result = Result.new(
          position: node.tag_opening.range.from,
          tag_opening: node.tag_opening.value,
          tag_closing: node.tag_closing.value,
          prefix: "  #",
          content: ruby_comment,
          location: node.location,
          node:
        )
        push_node(result)
      end

      # --- High-level operations ---

      # @rbs end_node: ::Herb::AST::erb_nodes
      def close_block(end_node) #: void
        adjust_last_output_prefix!
        block = pop_block
        current_block.concat(block)

        if block.size == 1 && block.first && !case_node?(block.first)
          placeholder = placeholder_builder.build(block.first, end_node)
          push_node(placeholder) if placeholder
        end

        push_erb_tag(end_node)
      end

      # @rbs result: Result
      def case_node?(result) #: bool
        result.node.is_a?(::Herb::AST::ERBCaseNode)
      end

      # @rbs node: ::Herb::AST::erb_nodes
      def build_ruby_code(node) #: String
        value = node.content.value
        if value.end_with?(" ")
          value.sub(/ ( *)$/, ';\1')
        else
          "#{value};"
        end
      end

      def adjust_last_output_prefix! #: void
        last_result = peek_node
        return unless last_result&.output?

        pop_node
        push_node(last_result.with(prefix: "   "))
      end

      def filter_comments! #: void
        current_block.reject!.with_index do |r, index|
          next false unless r.comment?

          following_results = current_block[(index + 1)...] || []
          following_results.any? do |other|
            r.same_line?(other) && !other.comment?
          end
        end
      end
    end
  end
end
