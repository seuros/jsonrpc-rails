require "bundler/setup"
require "rake/testtask"

# Configure the default test task
Rake::TestTask.new do |t|
  t.libs << "test"
  t.pattern = "test/**/*_test.rb" # Find tests recursively
  t.verbose = true # Show test output
end

# Load engine tasks (might define other test tasks, but the default is now configured)
APP_RAKEFILE = File.expand_path("test/dummy/Rakefile", __dir__)
load "rails/tasks/engine.rake"

# Load other tasks
load "rails/tasks/statistics.rake"
require "bundler/gem_tasks"

# Ensure the default task runs our configured test task
task default: :test
