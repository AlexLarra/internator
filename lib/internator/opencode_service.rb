require 'shellwords'
require 'open3'

module Internator
  class OpencodeService
    def initialize(instruction)
      @instruction = instruction
    end

    # Executes `opencode run "<instruction>"`.
    # When return_output is true, returns [stdout, exit_code]; otherwise returns exit code.
    def call(return_output: false)
      command = "opencode run #{Shellwords.escape(@instruction)}"
      if return_output
        stdout, _stderr, status = Open3.capture3(command)
        [stdout, status.exitstatus]
      else
        system(command)
        $?.exitstatus
      end
    end
  end
end
