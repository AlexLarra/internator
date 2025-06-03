require_relative "lib/internator/version"

Gem::Specification.new do |spec|
  spec.name          = "internator"
  spec.version       = Internator::VERSION
  spec.authors       = ["AlexLarra"]
  spec.email         = ["clausrybnic@gmail.com"]

  spec.summary       = "CLI tool that automates iterative pull request improvements using OpenAI's Codex"
  spec.description   = "Internator is a Ruby-based CLI tool that automates iterative pull request improvements using OpenAI's Codex. It cycles through objectives, makes incremental changes, automatically commits and pushes each update, and optionally waits between iterations."
  spec.homepage      = "https://github.com/AlexLarra/internator"
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*.rb") + ["README.md", "LICENSE", "internator.gemspec", "bin/internator"]
  spec.executables   = ["internator"]

  # Development dependencies for building and releasing the gem
  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake"
end
