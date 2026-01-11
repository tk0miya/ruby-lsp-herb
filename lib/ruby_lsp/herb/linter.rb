# frozen_string_literal: true

require "uri"
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
        uri = URI::File.build(path: File.expand_path(filename))
        result = ErbAnalyzer.new(uri, content).analyze.to_prism_parse_result

        if result.errors.any?
          puts "Errors:"
          result.errors.each do |error|
            location = error.location
            puts "- #{error.message} at #{filename}:#{location.start_line}:#{location.start_column}"
          end
        end

        return unless result.warnings.any?

        puts "Warnings:"
        result.warnings.each do |warning|
          location = warning.location
          puts "- #{warning.message} at #{filename}:#{location.start_line}:#{location.start_column}"
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
