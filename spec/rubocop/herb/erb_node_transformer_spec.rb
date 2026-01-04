# frozen_string_literal: true

require "herb"
require "ruby-lsp-herb"

RSpec.describe RuboCop::Herb::ERBNodeTransformer do
  describe ".call" do
    subject { described_class.call(node, following_nodes) }

    let(:parse_result) { Herb.parse(source) }
    let(:erb_nodes) do
      visitor = RuboCop::Herb::RubyExtractor::ErbNodeVisitor.new
      parse_result.visit(visitor)
      visitor.erb_nodes
    end
    let(:node) { erb_nodes[node_index] }
    let(:following_nodes) { erb_nodes[(node_index + 1)..] || [] }
    let(:node_index) { 0 }

    context "when multiple output tags at end of file" do
      let(:source) { "<%= foo %><%= bar %>" }

      context "with first output tag" do
        let(:node_index) { 0 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 1 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when multiple output tags before end" do
      let(:source) { "<% if x %><%= foo %><%= bar %><% end %>" }

      context "with first output tag" do
        let(:node_index) { 1 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 2 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when multiple output tags before else" do
      let(:source) { "<% if x %><%= foo %><%= bar %><% else %><% end %>" }

      context "with first output tag" do
        let(:node_index) { 1 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 2 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when multiple output tags before elsif" do
      let(:source) { "<% if x %><%= foo %><%= bar %><% elsif y %><% end %>" }

      context "with first output tag" do
        let(:node_index) { 1 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 2 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when multiple output tags before when" do
      let(:source) { "<% case x %><% when 1 %><%= foo %><%= bar %><% when 2 %><% end %>" }

      context "with first output tag" do
        let(:node_index) { 2 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 3 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when multiple output tags before in" do
      let(:source) { "<% case x %><% in 1 %><%= foo %><%= bar %><% in 2 %><% end %>" }

      context "with first output tag" do
        let(:node_index) { 2 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 3 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when multiple output tags before rescue" do
      let(:source) { "<% begin %><%= foo %><%= bar %><% rescue %><% end %>" }

      context "with first output tag" do
        let(:node_index) { 1 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 2 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when multiple output tags before ensure" do
      let(:source) { "<% begin %><%= foo %><%= bar %><% ensure %><% end %>" }

      context "with first output tag" do
        let(:node_index) { 1 }

        it "adds _ = prefix" do
          expect(subject.content).to eq("_ = foo;")
        end
      end

      context "with last output tag" do
        let(:node_index) { 2 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("    bar;")
        end
      end
    end

    context "when node is a statement tag (<%)" do
      let(:source) { "<% foo %><% bar %>" }

      context "with first statement tag" do
        let(:node_index) { 0 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("   foo;")
        end
      end

      context "with last statement tag" do
        let(:node_index) { 1 }

        it "does not add _ = prefix" do
          expect(subject.content).to eq("   bar;")
        end
      end
    end

    context "when content has trailing spaces" do
      let(:source) { "<%= foo   %>" }

      it "replaces first trailing space with semicolon" do
        expect(subject.content).to eq("    foo;  ")
      end
    end

    context "when content has no trailing spaces" do
      let(:source) { "<%=foo%>" }

      it "appends semicolon" do
        expect(subject.content).to eq("   foo;")
      end
    end
  end
end
