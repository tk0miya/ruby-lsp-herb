# frozen_string_literal: true

require "rubocop"
require "rubocop/lsp/stdin_runner"
require "ruby_lsp_herb"

RSpec.describe "RuboCop::Herb integration with StdinRunner" do # rubocop:disable RSpec/DescribeClass
  let(:config_store) do
    config_path = File.expand_path("../../../config/rubocop-herb/default.yml", __dir__)
    RuboCop::ConfigStore.new.tap { |store| store.options_config = config_path }
  end
  let(:runner) { RuboCop::Lsp::StdinRunner.new(config_store) }
  let(:path) { "test.html.erb" }

  before do
    RuboCop::Lsp::StdinRunner.ruby_extractors.unshift(RuboCop::Herb::RubyExtractor)
  end

  after do
    RuboCop::Lsp::StdinRunner.ruby_extractors.delete(RuboCop::Herb::RubyExtractor)
  end

  context "when ERB contains a Layout violation" do
    let(:source) { "<%= foo( ) %>" }

    it "detects offenses" do
      runner.run(path, source, {})
      cop_names = runner.offenses.map(&:cop_name)
      expect(cop_names).to eq(%w[Style/MethodCallWithoutArgsParentheses Layout/SpaceInsideParens])
    end
  end

  context "when ERB contains a Lint violation" do
    let(:source) { "<% x = 1 %>" }

    it "detects offenses" do
      runner.run(path, source, {})
      cop_names = runner.offenses.map(&:cop_name)
      expect(cop_names).to eq(%w[Lint/UselessAssignment])
    end
  end

  context "when ERB contains clean code" do
    let(:source) { "<%= user_name %>" }

    it "reports no offenses" do
      runner.run(path, source, {})
      expect(runner.offenses).to be_empty
    end
  end

  context "when multiple ERB tags are on the same line" do
    context "with if/end block" do
      let(:source) { "<% if user %><%= user.name %><% end %>" }

      it "detects only style offenses" do
        runner.run(path, source, {})
        cop_names = runner.offenses.map(&:cop_name)
        expect(cop_names).to eq(%w[Style/SafeNavigation])
      end
    end

    context "with do block" do
      let(:source) { "<% items.each do |item| %><%= item.name %><% end %>" }

      it "detects only style offenses" do
        runner.run(path, source, {})
        cop_names = runner.offenses.map(&:cop_name)
        expect(cop_names).to eq(%w[Style/BlockDelimiters Style/SymbolProc])
      end
    end

    context "with comment followed by code" do
      let(:source) { "<%# comment %><%= value %>" }

      it "parses correctly and reports no offenses" do
        runner.run(path, source, {})
        expect(runner.offenses).to be_empty
      end
    end

    context "with violation in one of the tags" do
      let(:source) { "<% if user %><%= foo( ) %><% end %>" }

      it "detects offenses" do
        runner.run(path, source, {})
        cop_names = runner.offenses.map(&:cop_name)
        expect(cop_names).to include("Layout/SpaceInsideParens")
      end
    end
  end

  context "when mixing output and statement tags" do
    context "with inline if expression using output tag" do
      let(:source) { "<%= if condition then 'yes' else 'no' end %>" }

      it "parses correctly and detects style offense" do
        runner.run(path, source, {})
        cop_names = runner.offenses.map(&:cop_name)
        expect(cop_names).to eq(%w[Style/OneLineConditional])
      end
    end

    context "with ternary operator" do
      let(:source) { "<%= condition ? 'yes' : 'no' %>" }

      it "parses correctly" do
        runner.run(path, source, {})
        expect(runner.offenses).to be_empty
      end
    end

    context "with case expression using output tag" do
      let(:source) { "<%= case x; when 1 then 'one'; else 'other'; end %>" }

      it "parses correctly" do
        runner.run(path, source, {})
        expect(runner.offenses).to be_empty
      end
    end
  end

  context "when ERB contains multibyte characters" do
    let(:source) { "<%= '日本語' %>" }

    it "parses correctly and reports no offenses" do
      runner.run(path, source, {})
      expect(runner.offenses).to be_empty
    end
  end

  context "when multi-line ERB with control flow structures" do
    context "with if-elsif-else block" do
      let(:source) do
        <<~ERB
          <% if user.admin? %>
            <p><%= user.name %></p>
          <% elsif user.guest? %>
            <p>Guest</p>
          <% else %>
            <p><%= user.email %></p>
          <% end %>
        ERB
      end

      it "parses correctly and reports no offenses" do
        runner.run(path, source, {})
        expect(runner.offenses).to be_empty
      end
    end

    context "with case-when-else block" do
      let(:source) do
        <<~ERB
          <% case role %>
          <% when :admin %>
            <p><%= admin_label %></p>
          <% when :editor %>
            <p>Editor</p>
          <% else %>
            <p>Guest</p>
          <% end %>
        ERB
      end

      it "parses correctly and reports no offenses" do
        runner.run(path, source, {})
        expect(runner.offenses).to be_empty
      end
    end

    context "with nested if inside loop" do
      let(:source) do
        <<~ERB
          <% users.each do |user| %>
            <% if user.active? %>
              <p><%= user.name %></p>
            <% else %>
              <p><%= user.email %></p>
            <% end %>
          <% end %>
        ERB
      end

      it "parses correctly and reports no offenses" do
        runner.run(path, source, {})
        expect(runner.offenses).to be_empty
      end
    end
  end
end
