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
      let(:expected) { ' div id=""; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with single-quoted attributes" do
      let(:source) { "<div id='x'>" }
      let(:expected) { ' div id=""; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multiple attributes" do
      let(:source) { '<div id="x" class="y">' }
      # class is a Ruby keyword, so it's converted to spaces
      let(:expected) { ' div id="";           ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute name" do
      let(:source) { '<div 属性="x">' }
      # Multibyte attribute names are preserved (not Ruby keywords)
      let(:expected) { ' div 属性=""; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute value" do
      let(:source) { '<div id="日">' }
      let(:expected) { ' div id="";   ' }

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
      # Single char attrs without quotes become ";", which triggers semicolon-after-tagname logic
      let(:expected) { " div;  " }

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

  describe "quote selection based on RuboCop config" do
    context "when config specifies double_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "double_quotes" }) }

      it "uses double quote for attribute" do
        result = transformer.transform_open_tag('<div id="x">', position: 0, location:).content
        expect(result).to eq(' div id=""; ')
      end

      it "converts HTML single quotes to RuboCop's preferred double quotes" do
        result = transformer.transform_open_tag("<div id='x'>", position: 0, location:).content
        expect(result).to eq(' div id=""; ')
      end
    end

    context "when config specifies single_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "single_quotes" }) }

      it "uses single quote for attribute" do
        result = transformer.transform_open_tag("<div id='x'>", position: 0, location:).content
        expect(result).to eq(" div id=''; ")
      end

      it "converts HTML double quotes to RuboCop's preferred single quotes" do
        result = transformer.transform_open_tag('<div id="x">', position: 0, location:).content
        expect(result).to eq(" div id=''; ")
      end
    end
  end
end
