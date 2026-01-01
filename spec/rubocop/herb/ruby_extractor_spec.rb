# frozen_string_literal: true

require "rubocop"
require "ruby-lsp-herb"

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

      context "when the ERB document contains a single ERB tag" do
        let(:source) { "<%= user_name %>" }

        it "extracts a single Ruby code fragment" do
          expect(subject).to match([
                                     {
                                       offset: 3,
                                       processed_source: an_instance_of(RuboCop::ProcessedSource)
                                                           .and(have_attributes(raw_source: " user_name "))
                                     }
                                   ])
        end
      end

      context "when the ERB document contains multiple ERB tags" do
        let(:source) { "<%= foo %>\n<%= bar %>" }

        it "extracts multiple Ruby code fragments" do
          expect(subject).to match([
                                     {
                                       offset: 3,
                                       processed_source: an_instance_of(RuboCop::ProcessedSource)
                                                           .and(have_attributes(raw_source: " foo "))
                                     },
                                     {
                                       offset: 14,
                                       processed_source: an_instance_of(RuboCop::ProcessedSource)
                                                           .and(have_attributes(raw_source: " bar "))
                                     }
                                   ])
        end
      end

      context "when the ERB document contains ERB comment tags" do
        let(:source) { "<%# This is a comment %>" }

        it "skips ERB comment tags" do
          expect(subject).to eq([])
        end
      end
    end
  end

  describe RuboCop::Herb::RubyExtractor::ErbNodeVisitor do
    subject { parse_result.visit(visitor) }

    let(:parse_result) { Herb.parse(source) }
    let(:visitor) { described_class.new }

    context "when the ERB document contains multiple ERB tags" do
      let(:source) { "<%= foo %>\n<%= bar %>" }

      it "collects ERB nodes" do
        subject
        expect(visitor.erb_nodes.size).to eq(2)
      end
    end

    context "when the ERB document contains comment nodes" do
      let(:source) { "<%# comment %><%= code %>" }

      it "collects ERB nodes except comment nodes" do
        subject
        expect(visitor.erb_nodes.size).to eq(1)
      end
    end
  end
end
