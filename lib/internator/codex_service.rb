require 'shellwords'

module Internator
  class CodexService
    def initialize(instruction)
      @instruction = instruction
    end

    # Executes `codex exec --full-auto` with the provided instruction.
    # @return [Integer] Exit code of the Codex process
    def call
      command = <<~CMD
        printenv OPENAI_API_KEY | codex login --with-api-key &&
        codex exec --full-auto #{Shellwords.escape(@instruction)}
      CMD
      system(command)
      $?.exitstatus
    end
  end
end
