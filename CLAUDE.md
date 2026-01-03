# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ruby-lsp-herb is a Ruby gem that provides Ruby LSP support for ERB templates using the Herb parser. It enables embedded Ruby linting in `.html.erb` files and integrates with RuboCop via a LintRoller plugin.

## Common Commands

```bash
# Run all tests
bundle exec rake spec

# Run RuboCop linting
bundle exec rake rubocop

# Run default task (spec + rubocop)
bundle exec rake

# Type checking with Steep
bundle exec steep check

# Process RBS inline annotations
bundle exec rbs-inline

# Run a single test file
bundle exec rspec spec/rubocop/herb/ruby_extractor_spec.rb

# Run a specific test by line number
bundle exec rspec spec/rubocop/herb/ruby_extractor_spec.rb:42
```

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

The project uses Steep with RBS inline annotations. Type signatures are in `sig/` directory. Run `bundle exec steep check` to verify types.

When modifying files, regenerate RBS signatures by running:
```bash
bundle exec rbs-inline --opt-out --output sig/ [filename]
```

## Testing Guidelines

### Unit Tests vs Integration Tests

- **Unit Tests** (`spec/`): Tests that verify functionality independently without external dependencies. Place tests here when the component can be tested in isolation.
- **Integration Tests** (`spec/rubocop/herb/integration_spec.rb`): Tests that require RuboCop integration. Place tests here when verifying end-to-end behavior with RuboCop.

### Development Workflow

After completing implementation, always run the full test suite and static analysis:
```bash
bundle exec rake
```

This runs `spec`, `rubocop`, and `steep` tasks to ensure code quality.

## Ruby Version

- Minimum required: Ruby 3.1.0
- CI runs on: Ruby 3.4.7
- Target version for RuboCop: 3.1
