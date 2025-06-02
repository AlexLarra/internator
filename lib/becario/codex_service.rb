module Becario
  # Service for executing the Codex CLI with full-auto mode
  class CodexService
    # @param instruction [String] Text instruction for Codex
    def initialize(instruction)
      @instruction = instruction
    end

    # Executes `codex --full-auto` with the provided instruction.
    # Streams stdout and stderr to the console in real time.
    # @return [Integer] Exit code of the Codex process
    def call
      command = [
        "codex",
        "--full-auto",
        "--quiet",
        "--writable-root", Dir.pwd,
        "--full-stdout",
        @instruction
      ]
      system(*command)
      $?.exitstatus
    end
  end
end