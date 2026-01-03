# frozen_string_literal: true

require_relative "lib/ruby_lsp/herb/version"

Gem::Specification.new do |spec|
  spec.name = "ruby-lsp-herb"
  spec.version = RubyLsp::Herb::VERSION
  spec.authors = ["Takeshi KOMIYA"]
  spec.email = ["i.tkomiya@gmail.com"]

  spec.summary = "Ruby LSP addon for ERB templates using Herb parser"
  spec.description = "Provides Ruby LSP support for ERB templates using the Herb parser. " \
                     "Enables embedded Ruby linting in .html.erb files and integrates with RuboCop " \
                     "via LintRoller plugin."
  spec.homepage = "https://github.com/tk0miya/ruby-lsp-herb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "herb", ">= 0.8.0"
  spec.add_dependency "lint_roller", ">= 1.1.0"
  spec.add_dependency "ruby-lsp"

  # LintRoller plugin metadata for RuboCop integration
  spec.metadata["default_lint_roller_plugin"] = "RuboCop::Herb::Plugin"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
