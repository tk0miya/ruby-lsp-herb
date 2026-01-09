# frozen_string_literal: true

require "herb"
require "rubocop"
require "ruby-lsp-herb"

RSpec.describe RuboCop::Herb::ErbNodeVisitor do
  let(:parse_result) { Herb.parse(source) }
  let(:config) { instance_double(RuboCop::Config, for_cop: { "EnforcedStyle" => "double_quotes" }) }
  let(:visitor) { described_class.new(source.bytes, encoding: source.encoding, config:) }

  describe "#results" do
    subject do
      parse_result.visit(visitor)
      visitor.results
    end

    describe "ERB content nodes" do
      context "with simple ERB tag" do
        let(:source) { "<% foo %>" }

        it "collects ERB node with correct attributes" do
          expect(subject.size).to eq(1)
          expect(subject.first).to have_attributes(position: 0, code: "   foo;")
        end
      end

      context "with output tag" do
        let(:source) { "<%= foo %>" }

        it "collects output tag with adjusted prefix for EOF" do
          expect(subject.size).to eq(1)
          expect(subject.first).to have_attributes(position: 0, code: "    foo;")
        end
      end

      context "with multiple output tags" do
        let(:source) { "<%= foo %><%= bar %>" }

        it "adjusts only the last output tag prefix" do
          expect(subject.size).to eq(2)
          expect(subject[0]).to have_attributes(position: 0, code: "_ = foo;")
          expect(subject[1]).to have_attributes(position: 10, code: "    bar;")
        end
      end
    end

    describe "comment nodes" do
      context "with comment on separate line" do
        let(:source) { "<%# comment %>\n<%= foo %>\n<% bar %>" }

        it "collects all ERB nodes" do
          expect(subject.size).to eq(3)
          expect(subject[0]).to have_attributes(position: 0, code: "  # comment ")
          expect(subject[1]).to have_attributes(position: 15, code: "_ = foo;")
          expect(subject[2]).to have_attributes(position: 26, code: "   bar;")
        end
      end

      context "with comment on same line as code" do
        let(:source) { "<%# comment %><%= foo %>\n<% bar %>" }

        it "filters out comment when on same line as code" do
          expect(subject.size).to eq(2)
          expect(subject[0]).to have_attributes(position: 14, code: "_ = foo;")
          expect(subject[1]).to have_attributes(position: 25, code: "   bar;")
        end
      end

      context "with single-line comment" do
        let(:source) { "<%# TODO: fix this %>" }

        it "transforms to Ruby comment" do
          expect(subject.size).to eq(1)
          expect(subject.first).to have_attributes(code: "  # TODO: fix this ")
        end
      end

      context "with multi-line comment" do
        let(:source) { "<%# line1\n   line2 %>" }

        it "transforms each line to Ruby comment" do
          expect(subject.size).to eq(1)
          expect(subject.first).to have_attributes(code: "  # line1\n  #line2 ")
        end
      end

      context "with multi-line comment with invalid indentation" do
        let(:source) { "<%# line1\nline2 %>" }

        it "ignores comment when indentation is invalid" do
          expect(subject.size).to eq(0)
        end
      end
    end

    describe "block nodes" do
      context "with do block (ERBBlockNode)" do
        let(:source) { "<% items.each do |item| %>\n  <%= item %>\n<% end %>" }

        it "collects block opening, content, and closing" do
          expect(subject.size).to eq(3)
          expect(subject[0]).to have_attributes(position: 0, code: "   items.each do |item|;")
          expect(subject[1]).to have_attributes(position: 29, code: "    item;")
          expect(subject[2]).to have_attributes(position: 41, code: "   end;")
        end
      end

      context "with empty do block" do
        let(:source) { "<% items.each do |item| %>\n    HTML\n<% end %>" }

        it "includes placeholder Result for empty blocks" do
          placeholder = subject.find { |r| r.code == "_ = nil;" }
          expect(placeholder).to have_attributes(code: "_ = nil;")
        end
      end

      context "with empty do block without enough space for placeholder" do
        let(:source) { "<% items.each do |item| %>\n<% end %>" }

        it "does not include placeholder when space is insufficient" do
          expect(subject.size).to eq(2)
          placeholder = subject.find { |r| r.code == "_ = nil;" }
          expect(placeholder).to be_nil
        end
      end
    end

    describe "if/elsif/else nodes" do
      context "with simple if" do
        let(:source) { "<% if condition %>\n  content\n<% end %>" }

        it "collects if and end nodes with placeholder" do
          expect(subject.size).to eq(3)
          expect(subject[0]).to have_attributes(code: "   if condition;")
          expect(subject[1]).to have_attributes(code: "_ = nil;")
          expect(subject[2]).to have_attributes(code: "   end;")
        end
      end

      context "with if/else" do
        let(:source) { "<% if x %>\n  a\n<% else %>\n  b\n<% end %>" }

        it "collects if, else, and end nodes" do
          codes = subject.map(&:code)
          expect(codes).to eq(["   if x;", "   else;", "   end;"])
        end
      end

      context "with if/elsif/else" do
        let(:source) { "<% if x %>\n  a\n<% elsif y %>\n  b\n<% else %>\n  c\n<% end %>" }

        it "collects all branch nodes" do
          codes = subject.map(&:code)
          expect(codes).to eq(["   if x;", "   elsif y;", "   else;", "   end;"])
        end
      end
    end

    describe "unless node" do
      context "with simple unless" do
        let(:source) { "<% unless condition %>\n  content\n<% end %>" }

        it "collects unless and end nodes" do
          expect(subject.size).to eq(3)
          expect(subject[0]).to have_attributes(code: "   unless condition;")
          expect(subject[2]).to have_attributes(code: "   end;")
        end
      end
    end

    describe "case/when nodes" do
      context "with case/when" do
        let(:source) { "<% case x %>\n<% when 1 %>\n  a\n<% when 2 %>\n  b\n<% end %>" }

        it "collects case and when nodes" do
          codes = subject.map(&:code)
          expect(codes).to eq(["   case x;", "   when 1;", "   when 2;", "   end;"])
        end
      end
    end

    describe "while node" do
      context "with simple while" do
        let(:source) { "<% while condition %>\n  content\n<% end %>" }

        it "collects while and end nodes" do
          expect(subject.first).to have_attributes(code: "   while condition;")
          expect(subject.last).to have_attributes(code: "   end;")
        end
      end
    end

    describe "until node" do
      context "with simple until" do
        let(:source) { "<% until condition %>\n  content\n<% end %>" }

        it "collects until and end nodes" do
          expect(subject.first).to have_attributes(code: "   until condition;")
          expect(subject.last).to have_attributes(code: "   end;")
        end
      end
    end

    describe "for node" do
      context "with simple for" do
        let(:source) { "<% for item in items %>\n  content\n<% end %>" }

        it "collects for and end nodes" do
          expect(subject.first).to have_attributes(code: "   for item in items;")
          expect(subject.last).to have_attributes(code: "   end;")
        end
      end
    end

    describe "begin/rescue/ensure nodes" do
      context "with begin/rescue" do
        let(:source) { "<% begin %>\n  risky\n<% rescue %>\n  handle\n<% end %>" }

        it "collects begin, rescue, and end nodes" do
          codes = subject.map(&:code)
          expect(codes).to eq(["   begin;", "   rescue;", "_ = nil;", "   end;"])
        end
      end

      context "with begin/rescue/ensure" do
        let(:source) { "<% begin %>\n  risky\n<% rescue %>\n  handle\n<% ensure %>\n  cleanup\n<% end %>" }

        it "collects all exception handling nodes" do
          codes = subject.map(&:code)
          expect(codes).to eq(["   begin;", "   rescue;", "_ = nil;", "   ensure;", "_ = nil;", "   end;"])
        end
      end

      context "with rescue with exception class" do
        let(:source) { "<% begin %>\n  risky\n<% rescue StandardError => e %>\n  handle\n<% end %>" }

        it "preserves rescue arguments" do
          codes = subject.map(&:code)
          expect(codes).to eq(["   begin;", "   rescue StandardError => e;", "_ = nil;", "   end;"])
        end
      end
    end

    describe "output tag prefix adjustment" do
      context "with output tag before block closing" do
        let(:source) { "<% if x %><%= foo %><% end %>" }

        it "adjusts output tag prefix to spaces before end" do
          expect(subject[1]).to have_attributes(code: "    foo;")
        end
      end

      context "with multiple output tags before block closing" do
        let(:source) { "<% if x %><%= foo %><%= bar %><% end %>" }

        it "uses _ = for first output, spaces for last" do
          expect(subject[1]).to have_attributes(code: "_ = foo;")
          expect(subject[2]).to have_attributes(code: "    bar;")
        end
      end

      context "with output tag at EOF" do
        let(:source) { "<%= foo %>" }

        it "adjusts output tag prefix to spaces" do
          expect(subject.first).to have_attributes(code: "    foo;")
        end
      end
    end

    describe "nested blocks" do
      context "with if inside each" do
        let(:source) do
          "<% items.each do |item| %>\n  <% if item.active? %>\n    <%= item.name %>\n  <% end %>\n<% end %>"
        end

        it "collects all nested nodes" do
          codes = subject.map(&:code)
          expect(codes).to eq([
                                "   items.each do |item|;", "   if item.active?;",
                                "    item.name;", "   end;", "   end;"
                              ])
        end
      end

      context "with case inside each" do
        let(:source) do
          "<% items.each do |item| %>\n  <% case item.type %>\n  <% when :a %>\n    a\n  " \
            "<% when :b %>\n    b\n  <% end %>\n<% end %>"
        end

        it "collects all nested nodes" do
          codes = subject.map(&:code)
          expect(codes).to eq([
                                "   items.each do |item|;", "   case item.type;",
                                "   when :a;", "   when :b;", "   end;", "   end;"
                              ])
        end
      end
    end

    describe "position tracking" do
      context "with simple tag" do
        let(:source) { "<%= foo %>" }

        it "tracks byte position correctly" do
          expect(subject.first).to have_attributes(position: 0)
        end
      end

      context "with HTML before ERB" do
        let(:source) { "<div><%= foo %></div>" }

        it "tracks byte position of HTML and ERB" do
          # First result is now the HTML open tag at position 0
          expect(subject[0]).to have_attributes(position: 0, content: "div; ")
          # Second result is the ERB tag at position 5
          expect(subject[1]).to have_attributes(position: 5)
          # Third result is the HTML close tag at position 15
          expect(subject[2]).to have_attributes(position: 15, content: "div1; ")
        end
      end

      context "with multibyte characters before ERB" do
        let(:source) { "日本語<%= foo %>" }

        it "tracks byte position correctly for multibyte" do
          expect(subject.first).to have_attributes(position: "日本語".bytesize)
        end
      end
    end
  end
end
