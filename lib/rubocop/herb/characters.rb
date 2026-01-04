# frozen_string_literal: true

module RuboCop
  module Herb
    # Character code constants used for byte manipulation in ERB extraction.
    module Characters
      LF = 10 #: Integer
      CR = 13 #: Integer
      SPACE = 32 #: Integer
      HASH = 35 #: Integer
      SEMICOLON = 59 #: Integer
      EQUALS = 61 #: Integer
      UNDERSCORE = 95 #: Integer
    end
  end
end
