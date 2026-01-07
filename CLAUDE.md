# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ruby-lsp-herb is a Ruby gem that provides Ruby LSP support for ERB templates using the Herb parser. It enables embedded Ruby linting in `.html.erb` files and integrates with RuboCop via a LintRoller plugin.

## Common Commands

```bash
# Run all tests
bin/rake spec

# Run RuboCop linting
bin/rake rubocop

# Run default task (spec + rubocop + steep)
bin/rake

# Type checking with Steep
bin/steep check

# Process RBS inline annotations
bin/rbs-inline

# Run a single test file
bin/rspec spec/rubocop/herb/ruby_extractor_spec.rb

# Run a specific test by line number
bin/rspec spec/rubocop/herb/ruby_extractor_spec.rb:42
```

Note: This project uses binstubs (`bin/`) instead of `bundle exec` for running commands.

## Architecture

### Two Main Integration Points

1. **Ruby LSP Addon** (`lib/ruby_lsp/herb/`)
   - `Addon` - LSP addon lifecycle management (activate/deactivate)
   - `HerbDocument` - Replaces ERBDocument for `.html.erb` files, parses using Herb
   - `Linter` - CLI linter that runs lint rules via visitor pattern
   - `patch/server.rb` and `patch/store.rb` - Monkey-patches Ruby LSP Server and Store to handle HerbDocument

2. **RuboCop Plugin** (`lib/rubocop/herb/`)
   - `Plugin` - LintRoller-based plugin that registers with RuboCop
   - `RubyExtractor` - Extracts Ruby code from ERB tags for RuboCop to lint

### Key Dependencies

- `herb` (>= 0.8.0) - HTML+ERB parser
- `ruby-lsp` - Ruby Language Server Protocol
- `lint_roller` - Plugin system for RuboCop integration

### Entry Points

- `lib/ruby-lsp-herb.rb` - Main gem entry point
- `exe/herb_lint.rb` - CLI executable for linting ERB files

## Type Checking

The project uses Steep with RBS inline annotations. Type signatures are in `sig/` directory. Run `bin/steep check` to verify types.

When modifying files, regenerate RBS signatures by running:
```bash
bin/rbs-inline --opt-out --output=sig/ [filename]
```

## Testing Guidelines

### Unit Tests vs Integration Tests

- **Unit Tests** (`spec/`): Tests that verify functionality independently without external dependencies. Place tests here when the component can be tested in isolation.
- **Integration Tests** (`spec/rubocop/herb/integration_spec.rb`): Tests that require RuboCop integration. Place tests here when verifying end-to-end behavior with RuboCop.

### Integration Test Assertions

In integration tests, always use `eq` matcher instead of `include` or `not_to include` when checking cop names. Using `include` only verifies part of the result and may miss other unexpected offenses:

```ruby
# Good - verifies the complete result
expect(cop_names).to eq(%w[Style/StringLiterals])
expect(cop_names).to eq([])

# Bad - may hide other problems
expect(cop_names).to include("Style/StringLiterals")
expect(cop_names).not_to include("Lint/EmptyBlock")
```

### Development Workflow

After completing implementation, always run the full test suite and static analysis:
```bash
bin/rake
```

This runs `spec`, `rubocop`, and `steep` tasks to ensure code quality.

## Ruby Version

- Minimum required: Ruby 3.1.0
- CI runs on: Ruby 3.4.7
- Target version for RuboCop: 3.1

## Development Tools

### Ruby Extractor Debug Script

To inspect extracted Ruby code from ERB templates (useful for debugging RubyExtractor):

```bash
# Pass ERB source as argument
ruby bin/extract_ruby.rb '<% if condition %><span>text</span><% end %>'

# Or via stdin
echo '<% if condition %><span>text</span><% end %>' | ruby bin/extract_ruby.rb
```

This script is for development only and is not included in the gem package.
