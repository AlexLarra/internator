require_relative "lib/becario/version"

Gem::Specification.new do |spec|
  spec.name          = "becario"
  spec.version       = Becario::VERSION
  spec.authors       = ["Alex Larra"]
  spec.email         = ["alex@example.com"]

  spec.summary       = "CLI tool that automates iterative pull request improvements using OpenAI's Codex"
  spec.description   = "Becario cycles through objectives, makes incremental changes, commits via your shell functions, and optionally waits between iterations."
  spec.homepage      = "https://github.com/your-username/becario"
  spec.license       = "MIT"

  spec.files         = Dir.glob("lib/**/*.rb") + ["README.md", "LICENSE", "becario.gemspec", "bin/becario"]
  spec.executables   = ["becario"]
  spec.require_paths = ["lib"]
end