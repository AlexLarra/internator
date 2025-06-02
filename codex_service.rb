#!/usr/bin/env ruby
#
# Service for executing the Codex CLI with full-auto mode
class CodexService
  # @param instruction [String] Text instruction for Codex
  def initialize(instruction)
    @instruction = instruction
  end

  # Executes `codex --full-auto` with the provided instruction.
  # Streams stdout and stderr to the console in real time, preserving TTY mode.
  # @return [Integer] Exit code of the Codex process
  # Example: codex -q --full-auto --writable-root . --full-stdout "Create a test.md file with a small lorem ipsum"
  def call
    # Run codex in full-auto, quiet mode, with project root writable,
    # and full stdout to avoid truncation.
    command = [
      'codex',
      '--full-auto',
      '--quiet',
      '--writable-root', Dir.pwd,
      '--full-stdout',
      @instruction
    ]
    # Use system to inherit STDIN as TTY, so Ink raw mode is supported
    system(*command)
    # Return the exit status of the command
    $?.exitstatus
  end
end

# Allow direct invocation from the command line without loading the full environment
if __FILE__ == $0
  if ARGV.empty?
    STDERR.puts "Usage: ruby #{$0} \"<instruction>\""
    exit 1
  end

  instruction = ARGV.join(' ')
  service = CodexService.new(instruction)
  exit service.call
end
