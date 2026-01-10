# frozen_string_literal: true

require "spec_helper"
require "rubocop/herb/configuration"

RSpec.describe RuboCop::Herb::Configuration do
  before do
    described_class.setup({})
  end

  after do
    described_class.setup({})
  end

  describe ".supported_file?" do
    subject { described_class.supported_file?(path) }

    context "with default extensions" do
      context "when path is .html.erb" do
        let(:path) { "app/views/home/index.html.erb" }

        it { is_expected.to be true }
      end

      context "when path is .erb" do
        let(:path) { "app/views/home/index.erb" }

        it { is_expected.to be false }
      end

      context "when path is .rb" do
        let(:path) { "app/models/user.rb" }

        it { is_expected.to be false }
      end
    end

    context "with custom extensions" do
      before do
        described_class.setup("extensions" => %w[.html.erb .erb])
      end

      context "when path is .html.erb" do
        let(:path) { "app/views/home/index.html.erb" }

        it { is_expected.to be true }
      end

      context "when path is .erb" do
        let(:path) { "app/views/home/index.erb" }

        it { is_expected.to be true }
      end

      context "when path is .rb" do
        let(:path) { "app/models/user.rb" }

        it { is_expected.to be false }
      end
    end
  end

  describe ".to_rubocop_config" do
    subject { described_class.to_rubocop_config }

    context "with default extensions" do
      it "returns AllCops Include with default glob" do
        expect(subject["AllCops"]["Include"]).to eq(["**/*.html.erb", "/**/*.html.erb"])
      end

      it "returns Exclude patterns for excluded cops" do
        expect(subject["Layout/BlockAlignment"]["Exclude"]).to eq(["**/*.html.erb", "/**/*.html.erb"])
        expect(subject["Style/FrozenStringLiteralComment"]["Exclude"]).to eq(["**/*.html.erb", "/**/*.html.erb"])
      end
    end

    context "with custom extensions" do
      before do
        described_class.setup("extensions" => %w[.html.erb .erb])
      end

      it "returns AllCops Include with custom globs" do
        expect(subject["AllCops"]["Include"]).to eq(["**/*.html.erb", "/**/*.html.erb", "**/*.erb", "/**/*.erb"])
      end

      it "returns Exclude patterns for excluded cops" do
        expected = ["**/*.html.erb", "/**/*.html.erb", "**/*.erb", "/**/*.erb"]
        expect(subject["Layout/BlockAlignment"]["Exclude"]).to eq(expected)
        expect(subject["Style/FrozenStringLiteralComment"]["Exclude"]).to eq(expected)
      end
    end
  end
end
