# frozen_string_literal: true

require "ruby_lsp/internal"
require "ruby-lsp-herb"

RSpec.describe RubyLsp::Herb::HerbDocument do
  let(:uri) { URI("file:///test.html.erb") }
  let(:version) { 1 }
  let(:global_state) { RubyLsp::GlobalState.new }

  def create_document(source)
    described_class.new(source:, version:, uri:, global_state:).tap(&:parse!)
  end

  describe "RuboCop integration" do
    before do
      RuboCop::Herb::Configuration.setup({})
    end

    context "when ERB has parse errors" do
      let(:source) { "<% if user %>" } # unclosed if block

      it "does not run RuboCop" do
        document = create_document(source)
        messages = document.parse_result.errors.map(&:message)

        expect(messages).to include(match(/unexpected/i))
        # RuboCop offenses should not be present since we skip on parse errors
        expect(messages.any? { |m| m.start_with?("[") }).to be false
      end
    end

    context "when ERB has no parse errors" do
      context "with RuboCop violations" do
        let(:source) { "<%= foo( ) %>" }

        it "includes RuboCop offenses as warnings" do
          document = create_document(source)
          messages = document.parse_result.warnings.map(&:message)

          expect(messages).to include(match(%r{\[Layout/SpaceInsideParens\]}))
          expect(messages).to include(match(%r{\[Style/MethodCallWithoutArgsParentheses\]}))
        end
      end

      context "with clean code" do
        let(:source) { "<%= user_name %>" }

        it "reports no RuboCop offenses" do
          document = create_document(source)
          messages = document.parse_result.warnings.map(&:message)

          # Should not have any RuboCop-prefixed messages
          expect(messages.any? { |m| m.start_with?("[") }).to be false
        end
      end

      context "with Herb Lint violations" do
        let(:source) { "<%=foo %>" } # missing space after <%=

        it "includes both Herb and RuboCop offenses" do
          document = create_document(source)
          messages = document.parse_result.warnings.map(&:message)

          # Herb Lint warning
          expect(messages).to include(match(/should start with a space or newline/))
        end
      end
    end

    context "with severity mapping" do
      context "with error severity offense" do
        # Lint/Syntax would be error level, but that requires actual syntax error
        # Most offenses are convention/warning level
        let(:source) { "<% x = 1 %>" } # Lint/UselessAssignment

        it "maps non-error offenses to warnings" do
          document = create_document(source)
          messages = document.parse_result.warnings.map(&:message)

          expect(messages).to include(match(%r{\[Lint/UselessAssignment\]}))
        end
      end
    end

    context "with location mapping" do
      let(:source) { "<%= foo( ) %>" } # Layout/SpaceInsideParens

      it "correctly maps offense location" do
        document = create_document(source)
        warning = document.parse_result.warnings.find { |w| w.message.include?("[Layout/SpaceInsideParens]") }

        expect(warning).not_to be_nil
        location = warning.location

        # The offense should be on the first line
        expect(location.start_line).to eq(1)
      end
    end
  end
end
