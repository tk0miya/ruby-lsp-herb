# frozen_string_literal: true

require "rubocop"
require "ruby-lsp-herb"

RSpec.describe RuboCop::Herb::HtmlTagTransformer do
  let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "double_quotes" }) }
  let(:transformer) { described_class.new(config) }
  let(:location) { instance_double(Herb::Location) }

  shared_examples "transforms HTML tag" do
    it "transforms to expected Ruby code with correct attributes" do
      expect(subject).to have_attributes(content: expected, position:, location:)
      expect(subject.content.bytesize).to eq(source.bytesize)
    end
  end

  describe "#transform_open_tag" do
    subject { transformer.transform_open_tag(source, position:, location:) }

    let(:position) { 0 }

    context "with simple tag without attributes" do
      let(:source) { "<div>" }
      let(:expected) { " div;" }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with attributes" do
      let(:source) { '<div id="x">' }
      # Quotes normalized to RuboCop's preferred style
      let(:expected) { ' div id="x" ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with single-quoted attributes" do
      let(:source) { "<div id='x'>" }
      # Single quotes converted to RuboCop's preferred quote (double)
      let(:expected) { ' div id="x" ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multiple attributes" do
      let(:source) { '<div id="x" class="y">' }
      # class is Ruby keyword → spaces; id preserved with quotes
      let(:expected) { ' div id="x"           ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute name" do
      let(:source) { '<div 属性="x">' }
      # Multibyte attr names are preserved (not Ruby keywords)
      let(:expected) { ' div 属性="x" ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute value" do
      let(:source) { '<div id="日">' }
      # Multibyte value preserved with quotes
      let(:expected) { ' div id="日" ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte boolean attribute" do
      let(:source) { "<div 属性>" }
      let(:expected) { " div      ; " }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with trailing space" do
      let(:source) { "<div >" }
      let(:expected) { " div ;" }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with attributes without quotes" do
      let(:source) { "<div disabled>" }
      let(:expected) { " div        ; " }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with single character attribute" do
      let(:source) { "<div x>" }
      # Single char attr without quotes: semicolon replaces it
      let(:expected) { " div ; " }

      it_behaves_like "transforms HTML tag"
    end

    context "with non-matching source" do
      let(:source) { "not a tag" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "with position" do
      let(:source) { "<div>" }
      let(:position) { 10 }

      it "sets position in result" do
        expect(subject.position).to eq(10)
      end
    end
  end

  describe "#transform_close_tag" do
    subject { transformer.transform_close_tag(source, position:, location:) }

    let(:position) { 0 }

    context "with simple close tag" do
      let(:source) { "</div>" }
      let(:expected) { " div1;" }

      it_behaves_like "transforms HTML tag"
    end

    context "with non-matching source" do
      let(:source) { "not a tag" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "with position" do
      let(:source) { "</div>" }
      let(:position) { 15 }

      it "sets position in result" do
        expect(subject.position).to eq(15)
      end
    end
  end

  describe "quote replacement" do
    it "normalizes quotes to RuboCop preferred style" do
      result = transformer.transform_open_tag('<div id="x">', position: 0, location:).content
      expect(result).to eq(' div id="x" ')
    end

    it "converts single quotes to RuboCop preferred double quotes" do
      result = transformer.transform_open_tag("<div id='x'>", position: 0, location:).content
      expect(result).to eq(' div id="x" ')
    end

    it "replaces class (Ruby keyword) with spaces but keeps other attributes" do
      result = transformer.transform_open_tag('<div id="x" class="admin">', position: 0, location:).content
      # class is a Ruby keyword, so it becomes spaces; id preserved with quotes
      expect(result).to eq(' div id="x"               ')
    end

    it "preserves both attrs when neither is a Ruby keyword" do
      result = transformer.transform_open_tag('<div id="x" data="y">', position: 0, location:).content
      expect(result).to eq(' div id="x" data="y" ')
    end
  end
end
