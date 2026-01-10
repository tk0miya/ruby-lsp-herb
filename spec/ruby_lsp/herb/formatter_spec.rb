# frozen_string_literal: true

require "ruby_lsp/herb/formatter"

RSpec.describe RubyLsp::Herb::Formatter do
  def format(source, path: "test.html.erb")
    described_class.new(source, path:).run
  end

  describe "#run" do
    context "when ERB has syntax errors" do
      it "returns nil" do
        source = "<% if true %>"
        expect(format(source)).to be_nil
      end
    end

    context "when ERB has no Ruby code" do
      it "returns nil (no changes needed)" do
        source = "<html><body>Hello</body></html>"
        expect(format(source)).to be_nil
      end
    end

    context "when formatting output tags" do
      it "returns nil when no changes needed" do
        source = "<%= user.name %>"
        result = format(source)
        expect(result).to be_nil
      end

      it "formats method calls with incorrect spacing" do
        source = "<%= foo(  1,2,3  ) %>"
        result = format(source)
        expect(result).to eq("<%= foo(1, 2, 3) %>")
      end

      it "formats hash rocket to new syntax" do
        source = "<%= { :foo => 'bar' } %>"
        result = format(source)
        expect(result).to eq("<%= { foo: 'bar' } %>")
      end
    end

    context "when formatting erb tags with incomplete Ruby code" do
      it "returns nil for block opening tags (incomplete Ruby cannot be formatted)" do
        # `if true` alone is not valid Ruby, so RuboCop cannot format it
        source = "<% if  true %><% end %>"
        result = format(source)
        expect(result).to be_nil
      end
    end

    context "when formatting erb tags with complete Ruby code" do
      it "formats method calls with extra spaces" do
        source = "<% puts  'hello' %>"
        result = format(source)
        expect(result).to eq("<% puts 'hello' %>")
      end

      it "formats operators without spaces" do
        source = "<% foo(1+2) %>"
        result = format(source)
        expect(result).to eq("<% foo(1 + 2) %>")
      end
    end

    context "when ERB has comment tags" do
      it "returns nil (comments are not formatted)" do
        source = "<%# this is a comment %>"
        result = format(source)
        expect(result).to be_nil
      end
    end

    context "with multiline ERB" do
      it "formats Ruby code in output tags with spacing issues" do
        source = <<~ERB
          <% if condition %>
            <%= foo(  1,2  ) %>
          <% end %>
        ERB
        result = format(source)
        expect(result).to include("foo(1, 2)")
      end
    end

    context "when no formatting changes are needed" do
      it "returns nil" do
        source = "<%= 'hello' %>"
        result = format(source)
        expect(result).to be_nil
      end
    end
  end
end
