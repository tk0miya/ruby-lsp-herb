# frozen_string_literal: true

require "rubocop"
require "ruby-lsp-herb"

RSpec.describe RuboCop::Herb::TextTransformer do
  let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "double_quotes" }) }
  let(:source_bytes) { source.bytes }
  let(:encoding) { Encoding::UTF_8 }
  let(:transformer) { described_class.new(source_bytes, encoding:, config:) }
  let(:location) do
    start_pos = instance_double(Herb::Position, line: 1, column: 0)
    instance_double(Herb::Location, start: start_pos)
  end

  shared_examples "transforms text" do
    it "transforms to expected Ruby code with correct attributes" do
      expect(subject).to have_attributes(content: expected, position: 0, location:)
      expect(subject.content.bytesize).to eq(source.bytesize)
    end
  end

  describe "#transform" do
    subject { transformer.transform(source, location:) }

    context "with simple text" do
      let(:source) { "string" }
      let(:expected) { '"tr"; ' }

      it_behaves_like "transforms text"
    end

    context "with exactly 5 characters" do
      let(:source) { "abcde" }
      let(:expected) { '"b"; ' }

      it_behaves_like "transforms text"
    end

    context "with exactly 4 characters" do
      let(:source) { "abcd" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "with 3 characters" do
      let(:source) { "abc" }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "with whitespace-only text" do
      let(:source) { "     " }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "with multibyte first character" do
      let(:source) { "日本語hello" }
      # "日" is 3 bytes, so opening quote + 2 spaces = 3 bytes
      # "llo" is 3 bytes, so '"; ' = 3 bytes (no padding needed)
      let(:expected) { '"  本語he"; ' }

      it_behaves_like "transforms text"
    end

    context "with multibyte last characters" do
      let(:source) { "hello日本語" }
      # "h" is 1 byte → '"' (1 byte)
      # middle: "ello" (4 bytes)
      # "日本語" is 9 bytes → '      "; ' (6 spaces + '"; ' = 9 bytes)
      let(:expected) { '"ello      "; ' }

      it_behaves_like "transforms text"
    end

    context "with all multibyte characters" do
      let(:source) { "日本語中文" }
      # "日" is 3 bytes → '"  ' (3 bytes)
      # middle: "本" (3 bytes)
      # "語中文" is 9 bytes → '      "; ' (6 spaces + 3 for '"; ' = 9 bytes)
      let(:expected) { '"  本      "; ' }

      it_behaves_like "transforms text"
    end

    context "with position on second line" do
      let(:source) { "first\nstring" }
      let(:location) do
        start_pos = instance_double(Herb::Position, line: 2, column: 0)
        instance_double(Herb::Location, start: start_pos)
      end
      let(:text) { "string" }

      it "calculates byte position correctly" do
        result = transformer.transform(text, location:)
        expect(result.position).to eq(6) # "first\n" is 6 bytes
      end
    end

    context "with column offset" do
      let(:source) { "prefix_string" }
      let(:location) do
        start_pos = instance_double(Herb::Position, line: 1, column: 7)
        instance_double(Herb::Location, start: start_pos)
      end
      let(:text) { "string" }

      it "calculates byte position correctly" do
        result = transformer.transform(text, location:)
        expect(result.position).to eq(7) # "prefix_" is 7 bytes
      end
    end
  end

  describe "preferred_quote" do
    subject { transformer.transform(source, location:)&.content }

    let(:source) { "string" }

    context "when config is nil" do
      let(:config) { nil }

      it "uses double quotes" do
        expect(subject).to eq('"tr"; ')
      end
    end

    context "when config specifies double_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "double_quotes" }) }

      it "uses double quotes" do
        expect(subject).to eq('"tr"; ')
      end
    end

    context "when config specifies single_quotes" do
      let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "single_quotes" }) }

      it "uses single quotes" do
        expect(subject).to eq("'tr'; ")
      end
    end
  end
end
