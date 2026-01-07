# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Run Steep type checking"
task :steep do
  sh "bin/rbs collection install --frozen"
  sh "bin/steep check"
end

task default: %i[spec rubocop steep]
