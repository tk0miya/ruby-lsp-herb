# frozen_string_literal: true

require "rubocop"
require "ruby_lsp_herb"

RSpec.describe RuboCop::Herb::ERBCommentTransformer do
  describe ".call" do
    subject { described_class.call(node, following_nodes) }

    let(:node) { erb_nodes.first }
    let(:erb_nodes) { extract_erb_nodes(source) }
    let(:following_nodes) { [] }

    def extract_erb_nodes(source)
      visitor = RuboCop::Herb::RubyExtractor::ErbNodeVisitor.new
      Herb.parse(source).visit(visitor)
      visitor.erb_nodes
    end

    context "when comment is single-line" do
      context "when not followed by other nodes" do
        let(:source) { "<%# TODO: fix %>" }

        it "returns content as-is" do
          expect(subject).to eq(" TODO: fix ")
        end
      end

      context "when followed by code on the same line" do
        let(:source) { "<%# comment %><%= value %>" }
        let(:following_nodes) { erb_nodes[1..] }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when followed by comment on the same line" do
        let(:source) { "<%# comment1 %><%# comment2 %>" }
        let(:following_nodes) { erb_nodes[1..] }

        it "returns content" do
          expect(subject).to eq(" comment1 ")
        end
      end

      context "when followed by multiple comments then code on the same line" do
        let(:source) { "<%# comment1 %><%# comment2 %><%= value %>" }
        let(:following_nodes) { erb_nodes[1..] }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when followed by code on a different line" do
        let(:source) { "<%# comment %>\n<%= value %>" }
        let(:following_nodes) { [] }

        it "returns content" do
          expect(subject).to eq(" comment ")
        end
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

      context "when followed by code on the same line" do
        let(:source) { "<%# line-1\n   line-2 %><%= value %>" }
        let(:following_nodes) { erb_nodes[1..] }

        it "returns nil" do
          expect(subject).to be_nil
        end
      end

      context "when followed by code on a different line" do
        let(:source) { "<%# line-1\n   line-2 %>\n<%= value %>" }
        let(:following_nodes) { [] }

        it "returns content" do
          expect(subject).to eq(" line-1\n  #line-2 ")
        end
      end
    end
  end
end
