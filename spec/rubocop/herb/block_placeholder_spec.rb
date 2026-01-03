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

    context "when there is exactly 3 characters of space" do
      let(:source) { "<% items.each do |item| %>...<% end %>" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when there is exactly 4 characters of space (minimum valid)" do
      let(:source) { "<% items.each do |item| %>....<% end %>" }

      it "returns a Result with nil; placeholder" do
        expect(subject).to be_a(described_class::Result)
        expect(subject.content.pack("C*")).to eq("nil;")
      end
    end

    context "when there is enough space between block and end on same line" do
      let(:source) { "<% items.each do |item| %>  <p>HTML</p>  <% end %>" }

      it "returns a Result with position and content" do
        expect(subject).to be_a(described_class::Result)
        expect(subject.position).to eq(26) # Right after first %>
        expect(subject.content.pack("C*")).to eq("nil;")
      end
    end

    context "when block and end are on different lines" do
      let(:source) { "<% items.each do |item| %>\n  <p>HTML</p>\n<% end %>" }

      it "returns a Result with position and content" do
        expect(subject).to be_a(described_class::Result)
        expect(subject.position).to eq(27) # After first newline
        expect(subject.content.pack("C*")).to eq("nil;")
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

      it "returns a Result with nil; placeholder" do
        expect(subject).to be_a(described_class::Result)
        expect(subject.content.pack("C*")).to eq("nil;")
      end
    end
  end
end
