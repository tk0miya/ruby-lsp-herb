# frozen_string_literal: true

require "herb"
require_relative "characters"
require_relative "configuration"
require_relative "erb_node_visitor"

module RuboCop
  module Herb
    # Extractor for extracting Ruby code from ERB templates using Herb parser.
    # This class is registered with RuboCop::Runner.ruby_extractors to enable
    # linting of Ruby code embedded in ERB files.
    class RubyExtractor
      include Characters

      # @rbs! type result = Array[{ offset: Integer, processed_source: ProcessedSource }]?

      attr_reader :processed_source #: RuboCop::ProcessedSource

      class << self
        # @rbs processed_source: RuboCop::ProcessedSource
        def call(processed_source) #: result
          new(processed_source).call
        end
      end

      # @rbs processed_source: RuboCop::ProcessedSource
      def initialize(processed_source) #: void
        @processed_source = processed_source
      end

      def call #: result
        path = processed_source.path
        return nil unless path && Configuration.supported_file?(path)

        parse_result = ::Herb.parse(processed_source.raw_source)
        return [] if parse_result.errors.any?

        unified_source = build_unified_ruby_source(parse_result)
        return [] if unified_source.nil?

        [{
          offset: 0,
          processed_source: build_processed_source(unified_source)
        }]
      end

      private

      # @rbs parse_result: Herb::ParseResult
      def build_unified_ruby_source(parse_result) #: String?
        original_source = processed_source.raw_source
        source_bytes = original_source.bytes
        visitor = ErbNodeVisitor.new(source_bytes)
        parse_result.visit(visitor)

        return nil if visitor.results.empty?

        result_bytes = build_result_bytes(source_bytes, visitor.results)
        result_bytes.pack("C*").force_encoding(original_source.encoding)
      end

      # @rbs source_bytes: Array[Integer]
      # @rbs results: Array[Result]
      def build_result_bytes(source_bytes, results) #: Array[Integer]
        result_bytes = source_bytes.map { |b| [LF, CR].include?(b) ? b : SPACE }

        results.each do |r|
          r.code.bytes.each_with_index do |byte, idx|
            result_bytes[r.position + idx] = byte
          end
        end

        result_bytes
      end

      # @rbs code: String
      def build_processed_source(code) #: RuboCop::ProcessedSource
        RuboCop::ProcessedSource.new(
          code,
          @processed_source.ruby_version,
          @processed_source.path,
          parser_engine: @processed_source.parser_engine
        ).tap do |source|
          source.config = @processed_source.config
          source.registry = @processed_source.registry
        end
      end
    end
  end
end
