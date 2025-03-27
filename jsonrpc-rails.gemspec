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

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/seuros/jsonrpc-rails"
  spec.metadata["changelog_uri"] = "https://github.com/seuros/jsonrpc-rails/blob/main/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.require_paths = [ "lib" ]

  spec.add_dependency "railties", ">= 8.0.1"
end
