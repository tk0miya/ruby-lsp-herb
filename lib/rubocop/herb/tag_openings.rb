# frozen_string_literal: true

module RuboCop
  module Herb
    # Utility module for ERB tag opening detection
    # Evaluates based on ERB semantics
    module TagOpenings
      # @rbs tag_opening: String
      def self.output?(tag_opening) #: bool
        tag_opening == "<%="
      end

      # ERB comment is only <%# ... %>
      # <%- # comment -%> is Ruby code (not ERB comment)
      # @rbs tag_opening: String
      def self.comment?(tag_opening) #: bool
        tag_opening == "<%#"
      end
    end
  end
end
