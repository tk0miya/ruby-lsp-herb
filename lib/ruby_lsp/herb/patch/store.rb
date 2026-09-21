# frozen_string_literal: true

require "ruby_lsp/store"

module RubyLsp
  class Store
    alias original_set set

    # @rbs override
    # @state and @global_state are part of RubyLsp::Store's private state and have no reader upstream.
    # rubocop:disable Style/InstanceVariableAccess
    def set(uri:, source:, version:, language_id:)
      @state[uri.to_s] = if language_id == :erb && uri.to_s.end_with?(".html.erb")
                           Herb::HerbDocument.new(source:, version:, uri:, global_state: @global_state)
                         else
                           original_set(uri:, source:, version:, language_id:)
                         end
    end
    # rubocop:enable Style/InstanceVariableAccess
  end
end
