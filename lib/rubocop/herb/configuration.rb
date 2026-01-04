# frozen_string_literal: true

module RuboCop
  module Herb
    # Configuration module for managing supported extensions.
    # This module is shared between RuboCop Plugin and Ruby LSP Addon.
    module Configuration
      DEFAULT_EXTENSIONS = %w[.html.erb].freeze #: Array[String]

      # @rbs self.@supported_extensions: Array[String]

      class << self
        # @rbs config: Hash[String, untyped]
        def setup(config) #: void
          @supported_extensions = config["extensions"] || DEFAULT_EXTENSIONS
        end

        # @rbs path: String
        def supported_file?(path) #: bool
          @supported_extensions.any? { |ext| path.end_with?(ext) }
        end
      end
    end
  end
end
