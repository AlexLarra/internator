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
      command = [
        "codex",
        "exec",
        "--full-auto",
        @instruction
      ]
      system(*command)
      $?.exitstatus
    end
  end
end
