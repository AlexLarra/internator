require 'shellwords'

module Internator
  class OpencodeService
    def initialize(instruction)
      @instruction = instruction
    end

    # Executes `opencode run "<instruction>"` with the provided instruction.
    # @return [Integer] Exit code of the Opencode process
    def call
      system("opencode run #{Shellwords.escape(@instruction)}")
      $?.exitstatus
    end
  end
end
