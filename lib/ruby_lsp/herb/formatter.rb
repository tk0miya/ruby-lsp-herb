# frozen_string_literal: true

require "herb"
require "prism"
require "ruby_lsp/requests/support/rubocop_runner"
require "rubocop/herb/erb_node_visitor"

module RubyLsp
  module Herb
    # Formatter for ERB files that formats Ruby code within ERB tags using RuboCop.
    # This class extracts Ruby code from ERB tags, formats each snippet with RuboCop's
    # auto-correct, and reconstructs the ERB file with the formatted Ruby code.
    class Formatter
      # Replacement data structure for tracking content changes
      Replacement = Data.define(
        :start_pos,   #: Integer - byte position of content start
        :end_pos,     #: Integer - byte position of content end
        :new_content  #: String - formatted Ruby code
      )

      # @rbs @source: String
      # @rbs @path: String
      # @rbs @encoding: Encoding
      # @rbs @rubocop_runner: untyped

      # @rbs source: String
      # @rbs path: String
      def initialize(source, path:) #: void
        @source = source
        @path = path
        @encoding = source.encoding
        @rubocop_runner = RubyLsp::Requests::Support::RuboCopRunner.new("-a")
      end

      def run #: String?
        parse_result = ::Herb.parse(@source)
        return nil if parse_result.errors.any?

        visitor = RuboCop::Herb::ErbNodeVisitor.new(
          @source.bytes,
          encoding: @encoding,
          config: @rubocop_runner.config_for_working_directory
        )
        parse_result.visit(visitor)

        results = visitor.results
        return nil if results.empty?

        format_erb(results)
      end

      private

      # Format ERB source by replacing Ruby code in each ERB tag with formatted version
      # @rbs results: Array[RuboCop::Herb::Result]
      def format_erb(results) #: String?
        # Collect replacements
        replacements = [] #: Array[Replacement]

        results.each do |result|
          next if result.comment? # Skip comment tags
          next unless result.node # Skip placeholders

          replacement = build_replacement(result)
          replacements << replacement if replacement
        end

        apply_replacements(replacements)
      end

      # Build a replacement for a single ERB tag
      # @rbs result: RuboCop::Herb::Result
      def build_replacement(result) #: Replacement?
        node = result.node
        return nil unless node

        original_content = node.content.value
        return nil if original_content.strip.empty?

        formatted_content = format_ruby_content(result, original_content)
        return nil unless formatted_content
        return nil if formatted_content == original_content

        content_start = node.content.range.from
        content_end = node.content.range.to

        Replacement.new(start_pos: content_start, end_pos: content_end, new_content: formatted_content)
      end

      # Format Ruby code content using RuboCop
      # @rbs result: RuboCop::Herb::Result
      # @rbs original_content: String
      def format_ruby_content(result, original_content) #: String?
        # Preserve leading/trailing whitespace
        leading_space = original_content[/\A\s*/]
        trailing_space = original_content[/\s*\z/]
        stripped_content = original_content.strip

        return nil if stripped_content.empty?

        # Create a complete Ruby statement for RuboCop to process
        ruby_source = build_ruby_source(result, stripped_content)
        return nil unless ruby_source

        formatted = run_rubocop(ruby_source)
        return nil unless formatted

        formatted_stripped = extract_formatted_content(formatted, result)
        return nil unless formatted_stripped

        # Restore leading/trailing whitespace
        "#{leading_space}#{formatted_stripped}#{trailing_space}"
      end

      # Build Ruby source code that RuboCop can process
      # @rbs result: RuboCop::Herb::Result
      # @rbs content: String
      def build_ruby_source(result, content) #: String?
        if result.output?
          # For output tags (<%= %>), wrap in assignment to make it a valid expression
          "_ = #{content}"
        else
          content
        end
      end

      # Run RuboCop auto-correct on Ruby source
      # @rbs ruby_source: String
      def run_rubocop(ruby_source) #: String?
        # Create a dummy parse result for RuboCop
        parse_result = Prism.parse_lex(ruby_source)

        @rubocop_runner.run(@path, ruby_source, parse_result)
        @rubocop_runner.formatted_source
      rescue StandardError
        nil
      end

      # Extract the formatted content from RuboCop output
      # @rbs formatted: String
      # @rbs result: RuboCop::Herb::Result
      def extract_formatted_content(formatted, result) #: String?
        if result.output?
          # Remove the "_ = " prefix we added
          formatted = formatted.sub(/\A_ = /, "")
        end

        # Remove trailing newline that RuboCop might add
        formatted.chomp
      end

      # Apply all replacements to the source string
      # @rbs replacements: Array[Replacement]
      def apply_replacements(replacements) #: String?
        return nil if replacements.empty?

        result = @source.dup
        # Sort by position descending to apply from end to start
        # This ensures earlier positions remain valid after each replacement
        replacements.sort_by { |r| -r.start_pos }.each do |r|
          result[r.start_pos...r.end_pos] = r.new_content
        end

        result
      end
    end
  end
end
