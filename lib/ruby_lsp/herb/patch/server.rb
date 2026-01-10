# frozen_string_literal: true

require "ruby_lsp/base_server"
require "ruby_lsp/server"
require_relative "../formatting"

module RubyLsp
  class Server < BaseServer
    alias original_text_document_diagnostic text_document_diagnostic
    alias original_text_document_formatting text_document_formatting

    # @rbs override
    def text_document_formatting(message) # rubocop:disable Metrics/AbcSize
      uri = message.dig(:params, :textDocument, :uri)
      path = uri.to_standardized_path
      unless path.nil? || path.start_with?(@global_state.workspace_path)
        send_empty_response(message[:id])
        return
      end

      document = @store.get(uri)

      # Delegate to original handler for non-ERB files
      unless document.is_a?(Herb::HerbDocument)
        original_text_document_formatting(message)
        return
      end

      result = Herb::Formatting.new(document, path: path || "untitled.html.erb").perform
      send_message(Result.new(id: message[:id], response: result))
    rescue Requests::Request::InvalidFormatter => e
      send_message(Notification.window_show_message(
                     "Configuration error: #{e.message}",
                     type: Constant::MessageType::ERROR
                   ))
      send_empty_response(message[:id])
    rescue StandardError, LoadError => e
      send_message(Notification.window_show_message(
                     "Formatting error: #{e.message}",
                     type: Constant::MessageType::ERROR
                   ))
      send_message(Notification.window_log_message(
                     "Formatting failed with\r\n: #{e.full_message}",
                     type: Constant::MessageType::ERROR
                   ))
      send_empty_response(message[:id])
    end

    # @rbs override
    def text_document_diagnostic(message) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
      # Do not compute diagnostics for files outside of the workspace. For example, if someone is looking at a gem's
      # source code, we don't want to show diagnostics for it
      uri = message.dig(:params, :textDocument, :uri)
      path = uri.to_standardized_path
      unless path.nil? || path.start_with?(@global_state.workspace_path)
        send_empty_response(message[:id])
        return
      end

      document = @store.get(uri)

      response = document.cache_fetch("textDocument/diagnostic") do |document|
        case document
        when Herb::HerbDocument, RubyDocument
          Requests::Diagnostics.new(@global_state, document).perform
        end
      end

      send_message(
        Result.new(
          id: message[:id],
          response: response && Interface::FullDocumentDiagnosticReport.new(kind: "full", items: response)
        )
      )
    rescue Requests::Request::InvalidFormatter => e
      send_message(Notification.window_show_message(
                     "Configuration error: #{e.message}",
                     type: Constant::MessageType::ERROR
                   ))
      send_empty_response(message[:id])
    rescue StandardError, LoadError => e
      send_message(Notification.window_show_message(
                     "Error running diagnostics: #{e.message}",
                     type: Constant::MessageType::ERROR
                   ))
      send_message(Notification.window_log_message(
                     "Diagnostics failed with\r\n: #{e.full_message}",
                     type: Constant::MessageType::ERROR
                   ))
      send_empty_response(message[:id])
    end
  end
end
