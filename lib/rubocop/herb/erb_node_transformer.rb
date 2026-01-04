# frozen_string_literal: true

require "herb"

module RuboCop
  module Herb
    # Transforms ERB nodes into Ruby code with proper formatting.
    # Returns the position and content for the transformation.
    class ERBNodeTransformer
      BLOCK_CLOSING_NODES = [
        ::Herb::AST::ERBEndNode,
        ::Herb::AST::ERBElseNode,
        ::Herb::AST::ERBWhenNode,
        ::Herb::AST::ERBInNode,
        ::Herb::AST::ERBRescueNode,
        ::Herb::AST::ERBEnsureNode
      ].freeze #: Array[class]

      Result = Data.define(
        :position, #: Integer
        :content #: String
      )

      attr_reader :node #: Herb::AST::erb_nodes
      attr_reader :following_nodes #: Array[Herb::AST::erb_nodes]

      # @rbs node: Herb::AST::erb_nodes
      # @rbs following_nodes: Array[Herb::AST::erb_nodes]
      def self.call(node, following_nodes) #: Result
        new(node, following_nodes).call
      end

      # @rbs node: Herb::AST::erb_nodes
      # @rbs following_nodes: Array[Herb::AST::erb_nodes]
      def initialize(node, following_nodes) #: void
        @node = node
        @following_nodes = following_nodes
      end

      def call #: Result
        Result.new(position:, content:)
      end

      private

      def position #: Integer
        node.tag_opening.range.from
      end

      def content #: String
        prefix + ruby_code
      end

      def prefix #: String
        if output_tag? && followed_by_block_body?
          "_ ="
        else
          " " * node.tag_opening.value.size
        end
      end

      def ruby_code #: String
        value = node.content.value

        if value.end_with?(" ")
          value.sub(/ ( *)$/, ';\1')
        else
          "#{value};"
        end
      end

      def output_tag? #: bool
        node.tag_opening.value == "<%="
      end

      def followed_by_block_body? #: bool
        next_node = following_nodes.first
        return false if next_node.nil?
        return false if BLOCK_CLOSING_NODES.any? { |klass| next_node.is_a?(klass) }
        return false if elsif_node?(next_node)

        true
      end

      # @rbs node: Herb::AST::erb_nodes
      def elsif_node?(node) #: bool
        node.is_a?(::Herb::AST::ERBIfNode) && node.content.value.lstrip.start_with?("elsif")
      end
    end
  end
end
