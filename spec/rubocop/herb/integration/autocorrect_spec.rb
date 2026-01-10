# frozen_string_literal: true

require "rubocop"
require "rubocop/lsp/stdin_runner"
require "ruby-lsp-herb"
require "tempfile"
require "yaml"

RSpec.describe "RuboCop::Herb autocorrect integration" do # rubocop:disable RSpec/DescribeClass
  subject { run_autocorrect(source) }

  let(:config_file) do
    Tempfile.new([".rubocop", ".yml"], Dir.pwd).tap do |f|
      config = RuboCop::Herb::Configuration.to_rubocop_config
      # Override Style/StringLiterals to prefer double quotes for testing
      config["Style/StringLiterals"] = { "EnforcedStyle" => "double_quotes" }
      f.write(YAML.dump(config))
      f.close
    end
  end
  let(:config_store) do
    RuboCop::ConfigStore.new.tap { |store| store.options_config = config_file.path }
  end
  let(:runner) { RuboCop::Lsp::StdinRunner.new(config_store) }
  let(:path) { "test.html.erb" }

  before do
    RuboCop::Herb::Configuration.setup({})
    RuboCop::Lsp::StdinRunner.ruby_extractors.unshift(RuboCop::Herb::RubyExtractor)
  end

  after do
    config_file.unlink
    RuboCop::Lsp::StdinRunner.ruby_extractors.delete(RuboCop::Herb::RubyExtractor)
  end

  def run_autocorrect(source)
    runner.run(path, source, { autocorrect: true })
    runner.formatted_source
  end

  context "with Style/StringLiterals offense" do
    context "with single output tag" do
      let(:source) { "<%= 'hello' %>" }
      let(:expected) { '<%= "hello" %>' }

      it { is_expected.to eq(expected) }
    end

    context "with multiple output tags" do
      let(:source) { "<%= 'foo' %><%= 'bar' %>" }
      let(:expected) { '<%= "foo" %><%= "bar" %>' }

      it { is_expected.to eq(expected) }
    end

    context "with output tag inside block" do
      let(:source) { "<% if x %><%= 'hello' %><% end %>" }
      let(:expected) { '<% if x %><%= "hello" %><% end %>' }

      it { is_expected.to eq(expected) }
    end

    context "with multi-line ERB" do
      let(:source) do
        <<~ERB.chomp
          <% if condition %>
            <%= 'value' %>
          <% end %>
        ERB
      end
      let(:expected) do
        <<~ERB.chomp
          <% if condition %>
            <%= "value" %>
          <% end %>
        ERB
      end

      it { is_expected.to eq(expected) }
    end

    context "with multibyte characters" do
      let(:source) { "<%= '日本語' %>" }
      let(:expected) { '<%= "日本語" %>' }

      it { is_expected.to eq(expected) }
    end
  end

  context "with Layout/SpaceInsideParens offense" do
    let(:source) { "<%= foo( ) %>" }
    # Also corrects Style/MethodCallWithoutArgsParentheses
    let(:expected) { "<%= foo %>" }

    it { is_expected.to eq(expected) }
  end

  context "with multiple correctable offenses" do
    let(:source) { "<%= foo( 'bar' ) %>" }
    let(:expected) { '<%= foo("bar") %>' }

    it { is_expected.to eq(expected) }
  end

  context "with leading newline in source" do
    let(:source) { "\n<%= 'hello' %>" }
    let(:expected) { "\n<%= \"hello\" %>" }

    it { is_expected.to eq(expected) }
  end

  context "with HTML before ERB tag" do
    let(:source) { "<p><%= 'hello' %></p>" }
    let(:expected) { '<p><%= "hello" %></p>' }

    it { is_expected.to eq(expected) }
  end

  # Style/IdenticalConditionalBranches autocorrect is disabled, so HTML tags remain unchanged
  context "with if-elsif-else block" do
    let(:source) do
      <<~ERB.chomp
        <% if user.admin? %>
          <p><%= 'Admin' %></p>
        <% elsif user.guest? %>
          <p><%= 'Guest' %></p>
        <% else %>
          <p><%= 'User' %></p>
        <% end %>
      ERB
    end
    let(:expected) do
      <<~ERB.chomp
        <% if user.admin? %>
          <p><%= "Admin" %></p>
        <% elsif user.guest? %>
          <p><%= "Guest" %></p>
        <% else %>
          <p><%= "User" %></p>
        <% end %>
      ERB
    end

    it { is_expected.to eq(expected) }
  end

  context "with case-when block" do
    let(:source) do
      <<~ERB.chomp
        <% case role %>
        <% when :admin %>
          <p><%= 'Admin' %></p>
        <% when :editor %>
          <p><%= 'Editor' %></p>
        <% else %>
          <p><%= 'Guest' %></p>
        <% end %>
      ERB
    end
    let(:expected) do
      <<~ERB.chomp
        <% case role %>
        <% when :admin %>
          <p><%= "Admin" %></p>
        <% when :editor %>
          <p><%= "Editor" %></p>
        <% else %>
          <p><%= "Guest" %></p>
        <% end %>
      ERB
    end

    it { is_expected.to eq(expected) }
  end

  context "with nested if inside loop" do
    let(:source) do
      <<~ERB.chomp
        <% users.each do |user| %>
          <% if user.active? %>
            <p><%= 'active' %></p>
          <% else %>
            <p><%= 'inactive' %></p>
          <% end %>
        <% end %>
      ERB
    end
    let(:expected) do
      <<~ERB.chomp
        <% users.each do |user| %>
          <% if user.active? %>
            <p><%= "active" %></p>
          <% else %>
            <p><%= "inactive" %></p>
          <% end %>
        <% end %>
      ERB
    end

    it { is_expected.to eq(expected) }
  end
end
