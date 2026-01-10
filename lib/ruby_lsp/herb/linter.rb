# frozen_string_literal: true

require "herb"
require "active_support/all"

module RubyLsp
  module Herb
    class Linter
      attr_reader :filename #: String?

      # @rbs args: Array[String]
      def initialize(args) #: void
        @filename = args.first
      end

      def run #: void # rubocop:disable Metrics/AbcSize
        raise "Filename is required" unless filename
        raise "File not found: #{filename}" unless File.exist?(filename)

        content = File.read(filename)
        result = ::Herb.parse(content)

        if result.errors.present?
          puts "Parse error:"
          result.errors.each do |error|
            puts "- #{error.message} at #{filename}:#{error.location.start.line}:#{error.location.start.column}"
          end
          return
        end

        # Herb Lint: ERB tag formatting rules
        visitor = MyVisitor.new
        result.visit(visitor)
        return unless visitor.herb_warnings.present?

        puts "Warnings:"
        visitor.herb_warnings.each do |warning|
          puts "- #{warning.message} at #{filename}:#{warning.location.start.line}:#{warning.location.start.column}"
        end
      end
    end

    class MyVisitor < ::Herb::Visitor
      attr_reader :herb_warnings #: Array[::Herb::Warnings::Warning]

      def initialize #: void
        @herb_warnings = []
        super
      end

      def visit_child_nodes(node) #: void
        visit_erb_nodes(node) if node.node_name.start_with?("ERB")
        super
      end

      def visit_erb_nodes(node) #: void
        unless node.content.value.start_with?(" ", "\n")
          warn("ERB tag should start with a space or newline", node.tag_opening.location)
        end

        unless node.content.value.end_with?(" ", "\n") # rubocop:disable Style/GuardClause
          warn("ERB tag should end with a space or newline", node.tag_closing.location)
        end
      end

      private

      # @rbs message: String
      # @rbs location: ::Herb::Location
      def warn(message, location) #: void
        herb_warnings << ::Herb::Warnings::Warning.new("warning", location, message)
      end
    end
  end
end
