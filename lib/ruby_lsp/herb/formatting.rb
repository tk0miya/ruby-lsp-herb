# frozen_string_literal: true

require "ruby_lsp/requests/request"
require_relative "formatter"

module RubyLsp
  module Herb
    # LSP formatting request handler for ERB files.
    # Returns TextEdit array to replace the document content with formatted version.
    class Formatting < RubyLsp::Requests::Request
      # @rbs document: HerbDocument
      # @rbs path: String
      def initialize(document, path:) #: void
        super()
        @document = document
        @path = path
      end

      def perform #: Array[Interface::TextEdit]?
        source = @document.source
        formatter = Formatter.new(source, path: @path)
        formatted_text = formatter.run
        return unless formatted_text

        # No changes needed
        return if formatted_text == source

        lines = source.lines

        [
          Interface::TextEdit.new(
            range: Interface::Range.new(
              start: Interface::Position.new(line: 0, character: 0),
              end: Interface::Position.new(line: lines.size, character: 0)
            ),
            new_text: formatted_text
          )
        ]
      end
    end
  end
end
