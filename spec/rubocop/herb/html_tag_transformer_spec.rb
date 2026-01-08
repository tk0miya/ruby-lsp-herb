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
      let(:expected) { 'div "d= x"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with single-quoted attributes" do
      let(:source) { "<div id='x'>" }
      let(:expected) { 'div "d= x"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multiple attributes" do
      let(:source) { '<div id="x" class="y">' }
      let(:expected) { 'div "d= x  class= y"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute name" do
      let(:source) { '<div 属性="x">' }
      let(:expected) { 'div "  性= x"; ' }

      it_behaves_like "transforms HTML tag"
    end

    context "with tag with multibyte attribute value" do
      let(:source) { '<div id="日">' }
      let(:expected) { 'div "d= 日"; ' }

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
    subject { transformer.transform_close_tag(source, position:, location:, open_tag_source:) }

    let(:position) { 0 }
    let(:open_tag_source) { "<div>" }

    context "with simple close tag" do
      let(:source) { "</div>" }
      # Hash of "<div>" maps to "G"
      let(:expected) { "divG; " }

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

    context "without open_tag_source" do
      let(:source) { "</div>" }
      let(:open_tag_source) { nil }

      it "uses fallback character '0'" do
        expect(subject.content).to eq("div0; ")
      end
    end
  end

  describe "hash-based closing tags" do
    it "produces identical closing tags for identical opening tags" do
      result1 = transformer.transform_close_tag("</div>", position: 0, location:,
                                                          open_tag_source: '<div id="foo">')
      result2 = transformer.transform_close_tag("</div>", position: 0, location:,
                                                          open_tag_source: '<div id="foo">')

      expect(result1.content).to eq(result2.content)
    end

    it "produces different closing tags for different opening tags" do
      result1 = transformer.transform_close_tag("</div>", position: 0, location:,
                                                          open_tag_source: '<div id="foo">')
      result2 = transformer.transform_close_tag("</div>", position: 0, location:,
                                                          open_tag_source: '<div id="bar">')

      # Different opening tags should typically produce different closing tags
      # (though hash collisions are theoretically possible)
      expect(result1.content).not_to eq(result2.content)
    end
  end

  describe "preferred_quote" do
    subject { transformer.transform_open_tag('<div id="x">', position: 0, location:).content }

    context "when config is nil" do
      let(:config) { nil }

      it "uses double quotes" do
        expect(subject).to eq('div "d= x"; ')
      end
    end

    context "when config specifies double_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "double_quotes" }) }

      it "uses double quotes" do
        expect(subject).to eq('div "d= x"; ')
      end
    end

    context "when config specifies single_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "single_quotes" }) }

      it "uses single quotes" do
        expect(subject).to eq("div 'd= x'; ")
      end
    end
  end
end
