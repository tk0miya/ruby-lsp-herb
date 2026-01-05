# frozen_string_literal: true

require "herb"
require "rubocop/herb/erb_node_visitor"

source = ARGV[0] || $stdin.read
source_bytes = source.bytes

parse_result = Herb.parse(source)
visitor = RuboCop::Herb::ErbNodeVisitor.new(source_bytes)
parse_result.visit(visitor)

result_bytes = source_bytes.map { |b| [10, 13].include?(b) ? b : 32 }
visitor.results.each do |r|
  r.code.bytes.each_with_index do |byte, idx|
    result_bytes[r.position + idx] = byte
  end
end

puts result_bytes.pack("C*").inspect
