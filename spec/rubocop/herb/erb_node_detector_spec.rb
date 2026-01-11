# frozen_string_literal: true

require "herb"
require "ruby-lsp-herb"

RSpec.describe RuboCop::Herb::ErbNodeDetector do
  describe ".detect?" do
    subject { described_class.detect?(node) }

    context "with ERB content node" do
      let(:source) { '<div class="<%= foo %>"></div>' }
      let(:node) { Herb.parse(source).value.children.first.open_tag }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "with ERB if node" do
      let(:source) { "<div <% if admin? %>class=\"admin\"<% end %>></div>" }
      let(:node) { Herb.parse(source).value.children.first.open_tag }

      it "returns true" do
        expect(subject).to be true
      end
    end

    context "without ERB" do
      let(:source) { '<div class="static"></div>' }
      let(:node) { Herb.parse(source).value.children.first.open_tag }

      it "returns false" do
        expect(subject).to be false
      end
    end
  end

  describe ".first_erb_position" do
    subject { described_class.first_erb_position(node) }

    context "with ERB content node" do
      let(:source) { '<div class="<%= foo %>"></div>' }
      let(:node) { Herb.parse(source).value.children.first.open_tag }

      it "returns the position of the ERB opening tag" do
        # "<div class="<%= foo %>">" - ERB starts at position 12
        expect(subject).to eq(12)
      end
    end

    context "with ERB if node" do
      let(:source) { "<div <% if admin? %>class=\"admin\"<% end %>></div>" }
      let(:node) { Herb.parse(source).value.children.first.open_tag }

      it "returns the position of the first ERB tag" do
        # "<div <% if admin? %>" - ERB starts at position 5
        expect(subject).to eq(5)
      end
    end

    context "with multiple ERB tags" do
      let(:source) { '<div class="<%= foo %> <%= bar %>"></div>' }
      let(:node) { Herb.parse(source).value.children.first.open_tag }

      it "returns the position of the first ERB tag" do
        expect(subject).to eq(12)
      end
    end

    context "without ERB" do
      let(:source) { '<div class="static"></div>' }
      let(:node) { Herb.parse(source).value.children.first.open_tag }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end
  end
end
