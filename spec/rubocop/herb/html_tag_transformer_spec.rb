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
      let(:expected) { "div; " }

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
      let(:expected) { ' div id="x  class= "; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute name" do
      let(:source) { '<div 属性="x">' }
      let(:expected) { 'div "  性= x"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute value" do
      let(:source) { '<div id="日">' }
      let(:expected) { ' div id=""  ; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte boolean attribute" do
      let(:source) { "<div 属性>" }
      let(:expected) { 'div "  "  ; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with trailing space" do
      let(:source) { "<div >" }
      let(:expected) { "div ; " }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with attributes without quotes" do
      let(:source) { "<div disabled>" }
      let(:expected) { 'div "isable"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with single character attribute" do
      let(:source) { "<div x>" }
      let(:expected) { "div  ; " }

      it_behaves_like "transforms HTML tag"
    end

    context "with single character attribute name and value" do
      let(:source) { '<div a="b">' }
      let(:expected) { ' div a=""; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with Ruby keyword as attribute name" do
      let(:source) { '<div class="foo">' }
      let(:expected) { 'div "lass= foo"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with for attribute (Ruby keyword)" do
      let(:source) { '<label for="input">' }
      let(:expected) { 'label "or= input"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with attribute name containing hyphen" do
      let(:source) { '<div data-url="https://example.com?a=1">' }
      let(:expected) { 'div "ata-url= https://example.com?a=1"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with empty attribute value" do
      let(:source) { '<div id="">' }
      let(:expected) { ' div id="; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with longer attribute values" do
      let(:source) { '<div id="foo" value="bar">' }
      let(:expected) { ' div id="foo  value= ba"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with valued attribute followed by boolean attribute" do
      let(:source) { '<div id="x" disabled>' }
      let(:expected) { ' div id="x  disabl"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with boolean attribute followed by valued attribute" do
      let(:source) { '<input disabled id="x">' }
      let(:expected) { 'input "isabled id= x"; ' }

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
      let(:expected) { "div1; " }

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

  describe "#transform_tag_name_only" do
    subject { transformer.transform_tag_name_only(tag_name, byte_length:, position:, location:) }

    let(:position) { 0 }

    context "with sufficient byte length" do
      let(:tag_name) { "div" }
      let(:byte_length) { 5 } # "<div " = 5 bytes

      it "transforms to tag name with semicolon" do
        expect(subject).to have_attributes(content: "div; ", position: 0, location:)
        expect(subject.content.bytesize).to eq(5)
      end
    end

    context "with extra byte length" do
      let(:tag_name) { "div" }
      let(:byte_length) { 8 }

      it "pads with spaces to match byte length" do
        expect(subject.content).to eq("div;    ")
        expect(subject.content.bytesize).to eq(8)
      end
    end

    context "with longer tag name" do
      let(:tag_name) { "section" }
      let(:byte_length) { 10 }

      it "transforms correctly" do
        expect(subject.content).to eq("section;  ")
        expect(subject.content.bytesize).to eq(10)
      end
    end

    context "with insufficient byte length" do
      let(:tag_name) { "div" }
      let(:byte_length) { 4 } # Too short for "div; " (5 bytes)

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "with very short byte length" do
      let(:tag_name) { "a" }
      let(:byte_length) { 3 } # Below minimum of 5

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "with position" do
      let(:tag_name) { "div" }
      let(:byte_length) { 5 }
      let(:position) { 10 }

      it "sets position in result" do
        expect(subject.position).to eq(10)
      end
    end
  end

  describe "preferred_quote" do
    subject { transformer.transform_open_tag('<div id="x">', position: 0, location:).content }

    context "when config is nil" do
      let(:config) { nil }

      it "uses double quotes" do
        expect(subject).to eq(' div id=""; ')
      end
    end

    context "when config specifies double_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "double_quotes" }) }

      it "uses double quotes" do
        expect(subject).to eq(' div id=""; ')
      end
    end

    context "when config specifies single_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "single_quotes" }) }

      it "uses single quotes" do
        expect(subject).to eq(" div id=''; ")
      end
    end
  end
end
