require 'shellwords'

module Internator
  # Service for executing the Codex CLI with full-auto mode
  class CodexService
    # @param instruction [String] Text instruction for Codex
    def initialize(instruction)
      @instruction = instruction
    end

    # Executes `codex --full-auto` with the provided instruction.
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
