# frozen_string_literal: true

require_relative "herb/addon"
require_relative "herb/herb_document"
require_relative "herb/linter"
require_relative "herb/logger"
require_relative "herb/patch/server"
require_relative "herb/patch/store"
require_relative "herb/version"

module RubyLsp
  module Herb
    class Error < StandardError; end
    # Your code goes here...
  end
end
