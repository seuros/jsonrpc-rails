require_relative "lib/jsonrpc_rails/version"

Gem::Specification.new do |spec|
  spec.name        = "jsonrpc-rails"
  spec.version     = JSON_RPC_Rails::VERSION
  spec.authors     = [ "Abdelkader Boudih" ]
  spec.email       = [ "terminale@gmail.com" ]
  spec.homepage    = "https://github.com/seuros/jsonrpc-rails"
  spec.summary     = "A Railtie-based gem that brings JSON-RPC 2.0 support to your Rails application."
  spec.description = "Integrates into Rails, allowing you to render JSON-RPC responses and validate incoming requests according to the JSON-RPC 2.0 specification. Includes middleware for strict request validation and a custom renderer. Designed for Rails 8+."
  spec.license     = "MIT"

  # Uncomment the following line and set the host if pushing to a private gem server.
  # spec.metadata["allowed_push_host"] = "http://mygemserver.com"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/seuros/jsonrpc-rails"
  # spec.metadata["changelog_uri"] = "https://github.com/seuros/jsonrpc-rails/blob/main/CHANGELOG.md" # Uncomment if CHANGELOG.md exists

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    # Include lib, license, Rakefile, README. Exclude test/dummy files from the gem package.
    Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  # spec.files = Dir.chdir(__dir__) { `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) } }
  # spec.bindir = "exe"
  # spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = [ "lib" ]


  spec.add_dependency "railties", ">= 8.0.1" # Keep existing dependency

  # Add development dependencies if needed, e.g.:
  # spec.add_development_dependency "rake", "~> 13.0"
  # spec.add_development_dependency "minitest", "~> 5.0"
end
