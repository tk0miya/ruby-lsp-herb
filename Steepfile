# frozen_string_literal: true

D = Steep::Diagnostic

target :lib do
  signature "sig"

  check "lib"

  # Ignore diagnostics for patch files that use ruby-lsp internal methods
  # and for files using ruby-lsp types that don't have complete RBS definitions
  configure_code_diagnostics(D::Ruby.default) do |hash|
    # Allow unknown constants from ruby-lsp (Interface::*, Support::*, etc.)
    hash[D::Ruby::UnknownConstant] = :hint
    # Allow methods from alias definitions
    hash[D::Ruby::NoMethod] = :hint
    # Allow undeclared method definitions for patch files
    hash[D::Ruby::UndeclaredMethodDefinition] = :hint
  end
end
