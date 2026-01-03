# frozen_string_literal: true

require "herb"
require "ruby-lsp-herb"

RSpec.describe RuboCop::Herb::BlockPlaceholder do
  describe ".build" do
    subject do
      parse_result = Herb.parse(source)
      visitor = RuboCop::Herb::RubyExtractor::ErbNodeVisitor.new
      parse_result.visit(visitor)
      erb_nodes = visitor.erb_nodes

      block_node = erb_nodes.find { |n| n.is_a?(Herb::AST::ERBBlockNode) }
      end_node = erb_nodes.find { |n| n.is_a?(Herb::AST::ERBEndNode) }
      result_bytes = source.bytes.map { |b| [10, 13].include?(b) ? b : 32 }

      described_class.build(block_node, end_node, result_bytes)
    end

    context "when block and end are adjacent on same line" do
      let(:source) { "<% items.each do |item| %><% end %>" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when there is exactly 2 characters of space (boundary)" do
      let(:source) { "<% items.each do |item| %>..<% end %>" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when there is exactly 3 characters of space (minimum valid)" do
      let(:source) { "<% items.each do |item| %>...<% end %>" }

      it "returns a Result with empty placeholder" do
        expect(subject).to be_a(described_class::Result)
        expect(subject.content.pack("C*")).to eq("'';")
      end
    end

    context "when there is enough space between block and end on same line" do
      let(:source) { "<% items.each do |item| %>  <p>HTML</p>  <% end %>" }

      it "returns a Result with position and content" do
        expect(subject).to be_a(described_class::Result)
        expect(subject.position).to eq(26) # Right after first %>
        # 15 chars available (  <p>HTML</p>  ), minus 3 = 12 space placeholder
        expect(subject.content.pack("C*")).to eq("'            ';")
      end
    end

    context "when block and end are on different lines" do
      let(:source) { "<% items.each do |item| %>\n  <p>HTML</p>\n<% end %>" }

      it "returns a Result with position and content" do
        expect(subject).to be_a(described_class::Result)
        expect(subject.position).to eq(27) # After first newline
        expect(subject.content).to be_an(Array)
        expect(subject.content.pack("C*")).to match(/^'.*';$/)
      end
    end

    context "when there is not enough space for placeholder" do
      let(:source) { "<% items.each do |item| %>\nX\n<% end %>" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when block content spans multiple lines with enough space" do
      let(:source) { "<% items.each do |item| %>\n          \n<% end %>" }

      it "returns a Result with correct placeholder size" do
        expect(subject).not_to be_nil
        content_str = subject.content.pack("C*")
        # 10 spaces available, minus 3 for quotes and semicolon = 7 space placeholder
        expect(content_str).to eq("'       ';")
      end
    end
  end
end
