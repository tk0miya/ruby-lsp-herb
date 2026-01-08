# frozen_string_literal: true

module RuboCop
  module Herb
    # Character code constants used for byte manipulation in ERB extraction.
    module Characters
      LF = 10 #: Integer
      CR = 13 #: Integer
      SPACE = 32 #: Integer
      SEMICOLON = 59 #: Integer
      DOUBLE_QUOTE = 34 #: Integer
      SINGLE_QUOTE = 39 #: Integer
    end
  end
end
