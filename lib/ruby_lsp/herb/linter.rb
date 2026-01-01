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
        else
          lint_html_erb(result)
          if result.warnings.present?
            puts "Warnings:"
            result.warnings.each do |warning|
              puts "- #{warning.message} at #{filename}:#{warning.location.start.line}:#{warning.location.start.column}"
            end
          end
        end
      end

      def lint_html_erb(result) #: void
        visitor = MyVisitor.new
        result.visit(visitor)
        visitor.offences.each do |message, location|
          result.warnings << ::Herb::Warnings::Warning.new("warning", location, message)
        end
      end
    end

    class MyVisitor < ::Herb::Visitor
      attr_reader :offences #: Array[[String, ::Herb::Location]]

      def initialize #: void
        @offences = []
        super
      end

      def visit_child_nodes(node) #: void
        visit_erb_nodes(node) if node.node_name.start_with?("ERB")
        super
      end

      def visit_erb_nodes(node) #: void
        unless node.content.value.start_with?(" ", "\n")
          offences << ["ERB tag should start with a space or newline", node.tag_opening.location]
        end

        unless node.content.value.end_with?(" ", "\n") # rubocop:disable Style/GuardClause
          offences << ["ERB tag should end with a space or newline", node.tag_closing.location]
        end
      end
    end
  end
end
