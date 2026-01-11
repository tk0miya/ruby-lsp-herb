# frozen_string_literal: true

require "herb"

module RuboCop
  module Herb
    # Visitor to detect if any ERB nodes exist in a subtree.
    # Used to check if HTML open tags contain ERB in attributes.
    class ErbNodeDetector < ::Herb::Visitor
      # Shortcut method to detect ERB nodes in a subtree.
      # @rbs node: untyped
      def self.detect?(node) #: bool
        detector = new
        detector.visit(node)
        detector.found?
      end

      def initialize #: void
        @found = false
        super
      end

      def found? #: bool
        @found
      end

      # Stop traversal once an ERB node is found.
      # @rbs node: untyped
      def visit(node) #: void
        return if @found

        super
      end

      # @rbs _node: ::Herb::AST::ERBContentNode
      def visit_erb_content_node(_node) #: void
        @found = true
      end

      # @rbs _node: ::Herb::AST::ERBBlockNode
      def visit_erb_block_node(_node) #: void
        @found = true
      end

      # @rbs _node: ::Herb::AST::ERBIfNode
      def visit_erb_if_node(_node) #: void
        @found = true
      end

      # @rbs _node: ::Herb::AST::ERBUnlessNode
      def visit_erb_unless_node(_node) #: void
        @found = true
      end

      # @rbs _node: ::Herb::AST::ERBCaseNode
      def visit_erb_case_node(_node) #: void
        @found = true
      end
    end
  end
end
