# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

desc "Run Steep type checking"
task :steep do
  # Use bundler version specified in Gemfile.lock to avoid compatibility issues
  bundler_version = File.read("Gemfile.lock")[/BUNDLED WITH\n\s+(\S+)/, 1]
  env = bundler_version ? { "BUNDLER_VERSION" => bundler_version } : {}
  # Use bin/rbs and bin/steep binstubs if available, fall back to bundle exec
  rbs_cmd = File.exist?("bin/rbs") ? "bin/rbs" : "bundle exec rbs"
  steep_cmd = File.exist?("bin/steep") ? "bin/steep" : "bundle exec steep"
  sh env, "#{rbs_cmd} collection install --frozen"
  sh env, "#{steep_cmd} check"
end

task default: %i[spec rubocop steep]
