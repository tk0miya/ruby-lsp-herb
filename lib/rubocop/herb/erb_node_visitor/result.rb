# frozen_string_literal: true

require_relative "tag_openings"

module RuboCop
  module Herb
    class ErbNodeVisitor
      # Result structure for transformed ERB nodes
      Result = Data.define(
        :position,      #: Integer - byte position
        :tag_opening,   #: String - opening tag ("<%=", "<%", "<%#", or "" for placeholder)
        :tag_closing,   #: String - closing tag ("%>" or "" for placeholder)
        :prefix,        #: String - transformed prefix ("_ =" or "   " or "" for placeholder)
        :content,       #: String - Ruby code with semicolon added
        :location,      #: ::Herb::Location - location info for same-line checking
        :node           #: ::Herb::AST::erb_nodes? - original AST node (nil for placeholders)
      )

      class Result
        def code #: String
          prefix + content
        end

        def output? #: bool
          TagOpenings.output?(tag_opening)
        end

        def comment? #: bool
          TagOpenings.comment?(tag_opening)
        end

        # Checks if this result is on the same line as another result.
        # Assumes self comes before other in document order.
        # @rbs other: Result
        def same_line?(other) #: bool
          location.end.line == other.location.start.line
        end
      end
    end
  end
end
