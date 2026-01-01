# frozen_string_literal: true

require "rubocop"
require "ruby_lsp_herb"

RSpec.describe RuboCop::Herb::RubyExtractor do
  describe ".call" do
    subject { described_class.call(processed_source) }

    let(:processed_source) { RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path) }

    context "when file is not .html.erb" do
      context "when file is .rb" do
        let(:source) { "x = 1" }
        let(:path) { "test.rb" }

        it { is_expected.to be_nil }
      end

      context "when file is .erb" do
        let(:source) { "<%= x %>" }
        let(:path) { "test.erb" }

        it { is_expected.to be_nil }
      end
    end

    context "when file is .html.erb" do
      let(:path) { "test.html.erb" }

      context "when HTML parsing fails" do
        let(:source) { "<%= unclosed" }

        it "returns empty array" do
          expect(subject).to eq([])
        end
      end

      context "when HTML parsing succeeds" do
        context "when HTML contains no ERB tags" do
          let(:source) { "<html><body></body></html>" }

          it "returns empty array" do
            expect(subject).to eq([])
          end
        end

        context "when HTML contains ERB tags" do
          shared_examples "extracts Ruby code" do
            it "returns extracted Ruby code with whitespace padding" do
              expect(subject).to match([
                                         {
                                           offset: 0,
                                           processed_source: an_instance_of(RuboCop::ProcessedSource)
                                                               .and(have_attributes(raw_source: expected))
                                         }
                                       ])
            end
          end

          context "when it contains multiple ERB tags" do
            let(:source) { "<%= foo %>\n<%= bar %>" }
            let(:expected) { "    foo   \n    bar   " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains ERB comment tags" do
            let(:source) { "<%# comment %>" }
            let(:expected) { "              " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains HTML tags" do
            let(:source) { "<p><%= x %></p>" }
            let(:expected) { "       x       " }

            it_behaves_like "extracts Ruby code"
          end
        end
      end
    end
  end

  describe RuboCop::Herb::RubyExtractor::ErbNodeVisitor do
    subject { parse_result.visit(visitor) }

    let(:parse_result) { Herb.parse(source) }
    let(:visitor) { described_class.new }
    let(:source) { "<%# comment %><%= foo %>\n<% bar %>" }

    it "collects all ERB nodes" do
      subject
      expect(visitor.erb_nodes.size).to eq(3)
    end
  end
end
