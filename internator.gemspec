require_relative "lib/internator/version"

Gem::Specification.new do |spec|
  spec.name          = "internator"
  spec.version       = Internator::VERSION
  spec.authors       = ["AlexLarra"]
  spec.email         = ["clausrybnic@gmail.com"]

  spec.summary       = "CLI tool that automates iterative pull request improvements using OpenAI's Codex"
  spec.description   = "Internator cycles through objectives, makes incremental changes, commits via your shell functions, and optionally waits between iterations."
  spec.homepage      = "https://github.com/your-username/internator"
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*.rb") + ["README.md", "LICENSE", "internator.gemspec", "bin/internator"]
  spec.executables   = ["internator"]
  spec.require_paths = ["lib"]
end
