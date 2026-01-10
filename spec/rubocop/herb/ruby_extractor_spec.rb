# frozen_string_literal: true

require "rubocop"
require "ruby-lsp-herb"

RSpec.describe RuboCop::Herb::RubyExtractor do
  before do
    RuboCop::Herb::Configuration.setup({})
  end

  describe ".call" do
    subject { described_class.call(processed_source) }

    let(:processed_source) { RuboCop::ProcessedSource.new(source, RUBY_VERSION.to_f, path) }

    context "when file is not .html.erb" do
      context "when file is .rb" do
        let(:source) { "x = 1" }
        let(:path) { "test.rb" }

        it { is_expected.to be_nil }
      end

      context "when file is .erb" do
        let(:source) { "<%= x %>" }
        let(:path) { "test.erb" }

        it { is_expected.to be_nil }
      end
    end

    context "when file is .html.erb" do
      let(:path) { "test.html.erb" }

      context "when HTML parsing fails" do
        let(:source) { "<%= unclosed" }

        it "returns empty array" do
          expect(subject).to eq([])
        end
      end

      context "when HTML parsing succeeds" do
        shared_examples "extracts Ruby code" do
          it "returns extracted Ruby code with whitespace padding" do
            # With offset: 1, the first character is removed, so expected.size + 1 == source.size
            expect(source.size).to eq(expected.size + 1)
            expect(subject).to match([
                                       {
                                         offset: 1,
                                         processed_source: an_instance_of(RuboCop::ProcessedSource)
                                                             .and(have_attributes(raw_source: expected))
                                       }
                                     ])
          end
        end

        context "when HTML contains no ERB tags" do
          let(:source) { "<html><body></body></html>" }
          let(:expected) { "tml; body; body1; html2; " }

          it_behaves_like "extracts Ruby code"
        end

        context "when HTML contains ERB tags" do
          context "when it contains multiple ERB tags" do
            let(:source) { "<%= foo %>\n<%= bar %>" }
            let(:expected) { "   foo;  \n    bar;  " }

            it_behaves_like "extracts Ruby code"
          end

          context "when multiple output tags before block-closing node" do
            let(:source) { "<% if x %><%= foo %><%= bar %><% end %>" }
            let(:expected) { "  if x;  _ = foo;      bar;     end;  " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains single-line ERB comment" do
            let(:source) { "<%# TODO: fix %>" }
            let(:expected) { " # TODO: fix   " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains indented single-line ERB comment" do
            let(:source) { "    <%# note %>" }
            let(:expected) { "     # note   " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains HTML tags" do
            let(:source) { "<p><%= x %></p>" }
            let(:expected) { "; _ = x;  p1; " }

            it_behaves_like "extracts Ruby code"
          end

          context "when multiple ERB tags are on same line" do
            context "with simple statements" do
              let(:source) { "<% if user %><%= user.name %><% end %>" }
              let(:expected) { "  if user;      user.name;     end;  " }

              it_behaves_like "extracts Ruby code"
            end

            context "with no spaces around content" do
              let(:source) { "<%foo%><%bar%>" }
              let(:expected) { " foo;   bar; " }

              it_behaves_like "extracts Ruby code"
            end

            context "with do block" do
              let(:source) { "<% items.each do |item| %><%= item.name %><% end %>" }
              let(:expected) { "  items.each do |item|;      item.name;     end;  " }

              it_behaves_like "extracts Ruby code"
            end

            context "with do block without params" do
              let(:source) { "<% loop do %><%= x %><% end %>" }
              let(:expected) { "  loop do;      x;     end;  " }

              it_behaves_like "extracts Ruby code"
            end

            context "with unless block containing HTML" do
              let(:source) { "<% unless condition %><span>text</span><% end %>" }
              let(:expected) { "  unless condition;  span;     span1;    end;  " }

              it_behaves_like "extracts Ruby code"
            end

            context "with comment followed by code" do
              let(:source) { "<%# comment %><%= value %>" }
              # Comment is ignored, only code is extracted
              let(:expected) { "                 value;  " }

              it_behaves_like "extracts Ruby code"
            end

            context "with multi-line comment followed by code" do
              let(:source) { "<%# long\n   comment %><%= value %>" }
              # Comment is ignored, only code is extracted
              let(:expected) { "       \n                 value;  " }

              it_behaves_like "extracts Ruby code"
            end

            context "with multiple comments on same line" do
              let(:source) { "<%# comment1 %><%# comment2 %>" }
              # All comments should be rendered
              let(:expected) { " # comment1     # comment2   " }

              it_behaves_like "extracts Ruby code"
            end

            context "with multiple comments followed by code" do
              let(:source) { "<%# comment1 %><%# comment2 %><%= value %>" }
              # All comments are ignored when followed by code
              let(:expected) { "                                 value;  " }

              it_behaves_like "extracts Ruby code"
            end
          end

          context "when do block contains only HTML content" do
            let(:source) { "<% items.each do |item| %>\n  <p>HTML</p>\n<% end %>" }
            let(:expected) { "  items.each do |item|;  \n  p;     p1; \n   end;  " }

            it_behaves_like "extracts Ruby code"
          end

          context "when do block contains HTML and Ruby" do
            let(:source) { "<% items.each do |item| %>\n  <p><%= item %></p>\n<% end %>" }
            let(:expected) { "  items.each do |item|;  \n  p; _ = item;  p1; \n   end;  " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains if-elsif-else" do
            let(:source) { "<% if x %>\n  a\n<% elsif y %>\n  b\n<% else %>\n  c\n<% end %>" }
            let(:expected) { "  if x;  \n   \n   elsif y;  \n   \n   else;  \n   \n   end;  " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains case-when-else" do
            let(:source) { "<% case x %>\n<% when 1 %>\n  a\n<% when 2 %>\n  b\n<% else %>\n  c\n<% end %>" }
            let(:expected) { "  case x;  \n   when 1;  \n   \n   when 2;  \n   \n   else;  \n   \n   end;  " }

            it_behaves_like "extracts Ruby code"
          end

          context "when it contains multibyte characters" do
            let(:source) { "<%= \"日本語\" %>" }
            let(:expected) { "   \"日本語\";  " }

            it_behaves_like "extracts Ruby code"

            it "preserves byte positions" do
              result = subject
              # With offset: 1, the first byte is removed, so bytesize + 1 == source.bytesize
              expect(result[0][:processed_source].raw_source.bytesize).to eq(source.bytesize - 1)
            end
          end

          context "when it contains ERB tags with whitespace trim prefix" do
            context "with <%- (statement tag)" do
              let(:source) { "<%- foo -%>" }
              let(:expected) { "   foo;   " }

              it_behaves_like "extracts Ruby code"
            end

            context "with <%- containing Ruby comment" do
              let(:source) { "<%- # TODO -%>" }
              let(:expected) { "   # TODO;   " }

              it_behaves_like "extracts Ruby code"
            end

            context "with mixed normal and whitespace trim tags" do
              let(:source) { "<%= foo %>\n<%- bar -%>" }
              let(:expected) { "   foo;  \n    bar;   " }

              it_behaves_like "extracts Ruby code"
            end

            context "with <%- inside block" do
              let(:source) { "<% if x %><%- foo -%><% end %>" }
              let(:expected) { "  if x;      foo;      end;  " }

              it_behaves_like "extracts Ruby code"
            end
          end
        end
      end
    end
  end
end
