# frozen_string_literal: true

require "rubocop"
require "ruby_lsp_herb"

RSpec.describe RuboCop::Herb::ERBCommentTransformer do
  describe ".call" do
    subject { described_class.call(node) }

    let(:node) { extract_erb_node(source) }

    def extract_erb_node(source)
      visitor = RuboCop::Herb::RubyExtractor::ErbNodeVisitor.new
      Herb.parse(source).visit(visitor)
      visitor.erb_nodes.first
    end

    context "when comment is single-line" do
      let(:source) { "<%# TODO: fix %>" }

      it "returns content as-is" do
        expect(subject).to eq(" TODO: fix ")
      end
    end

    context "when comment is multi-line" do
      context "with aligned indentation (all continuation lines have enough whitespace)" do
        let(:source) { "<%# line-1\n   line-2\n   line-3 %>" }

        it "places # at target column for all continuation lines" do
          # tag at column 0, # at column 2, so continuation lines get # at column 2
          expect(subject).to eq(" line-1\n  #line-2\n  #line-3 ")
        end
      end

      context "with indented tag and aligned continuation lines" do
        let(:source) { "    <%# line-1\n       line-2 %>" }

        it "places # at target column (tag column + 2)" do
          # tag starts at column 4, so # should be at column 6
          expect(subject).to eq(" line-1\n      #line-2 ")
        end
      end

      context "with mixed indentation (some lines fall back to position 0)" do
        let(:source) { "<%# line-1\n line-2 %>" }

        it "places # at position 0 when target column has no whitespace" do
          expect(subject).to eq(" line-1\n#line-2 ")
        end
      end

      context "with deeply indented tag and shallow continuation" do
        let(:source) { "        <%# line-1\n  line-2 %>" }

        it "falls back to position 0 for shallow continuation lines" do
          # tag at column 8, target column 10, but line-2 only has 2 spaces
          expect(subject).to eq(" line-1\n# line-2 ")
        end
      end

      context "when continuation line has no leading whitespace" do
        let(:source) { "<%# line-1\nline-2 %>" }

        it "returns nil (unsupported)" do
          expect(subject).to be_nil
        end
      end

      context "when any continuation line has no leading whitespace" do
        let(:source) { "<%# line-1\n   line-2\nline-3 %>" }

        it "returns nil (unsupported)" do
          expect(subject).to be_nil
        end
      end
    end
  end
end
