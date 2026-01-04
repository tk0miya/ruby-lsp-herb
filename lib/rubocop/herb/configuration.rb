# frozen_string_literal: true

module RuboCop
  module Herb
    # Configuration module for managing supported extensions.
    # This module is shared between RuboCop Plugin and Ruby LSP Addon.
    module Configuration
      DEFAULT_EXTENSIONS = %w[.html.erb].freeze #: Array[String]

      # @rbs self.@supported_extensions: Array[String]

      # Cops to exclude from ERB files due to whitespace padding and ERB tag formatting
      EXCLUDED_COPS = [
        "Layout/BlockAlignment",          # Block alignment differs due to ERB tag length differences (<%= vs <%)
        "Layout/CommentIndentation",      # ERB comment to Ruby comment conversion shifts column position
        "Layout/EndAlignment",            # ERB tags have different lengths, making end alignment appear incorrect
        "Layout/ExtraSpacing",            # Whitespace padding preserves character positions but creates extra spaces
        "Layout/IndentationConsistency",  # Ruby code in HTML+ERB files may be aligned differently
        "Layout/IndentationWidth",        # Ruby code in HTML+ERB files may have different indentation width
        "Layout/InitialIndentation",      # Ruby code in HTML+ERB files may have different indentation rules
        "Layout/LeadingEmptyLines",       # Non-Ruby tags may be inserted before Ruby code
        "Layout/TrailingEmptyLines",      # Layout cops may conflict with ERB template formatting
        "Layout/TrailingWhitespace",      # Extracted Ruby code from ERB may have trailing whitespace
        "Lint/EmptyConditionalBody",      # Control flow bodies may contain only HTML (no Ruby code)
        "Lint/EmptyWhen",                 # Case/when bodies may contain only HTML (no Ruby code)
        "Style/EmptyElse",                # Else branches may contain only HTML (no Ruby code)
        "Style/FrozenStringLiteralComment", # ERB files don't have frozen string literal comments
        "Style/IfUnlessModifier",         # Conditional HTML wrapping is extracted as single line
        "Style/IfWithSemicolon",          # Semicolons are inserted between ERB tags on the same line
        "Style/Next",                     # `next unless` style is less readable than if/end in ERB templates
        "Style/Semicolon"                 # Semicolons are inserted between ERB tags on the same line
      ].freeze #: Array[String]

      class << self
        # @rbs config: Hash[String, untyped]
        def setup(config) #: void
          @supported_extensions = config["extensions"] || DEFAULT_EXTENSIONS
        end

        # @rbs path: String
        def supported_file?(path) #: bool
          @supported_extensions.any? { |ext| path.end_with?(ext) }
        end

        def to_rubocop_config #: Hash[String, untyped]
          globs = @supported_extensions.map { |ext| "**/*#{ext}" }

          config = { "AllCops" => { "Include" => globs } }
          EXCLUDED_COPS.each do |cop|
            config[cop] = { "Exclude" => globs }
          end
          config
        end
      end
    end
  end
end
