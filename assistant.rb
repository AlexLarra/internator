#!/usr/bin/env ruby
# assistant.rb
# Note: This script requires the shell functions `iacommit()` and `ask_openai()`
# These functions are available at:
#   https://github.com/AlexLarra/dotfiles/blob/master/sh/sh_functions
# Make sure to load these functions into your shell environment (e.g., in .zshrc or .bashrc).
require_relative 'codex_service'

# Parse command-line arguments: PR objectives and optional delay between iterations
usage = "❌ Usage: ruby #{File.basename($0)} \"<PR Objectives>\" [delay_mins]"
abort(usage) if ARGV.empty? || ARGV.size > 2

OBJECTIVES = ARGV[0]
delay_mins = if ARGV[1]
               begin
                 Integer(ARGV[1])
               rescue ArgumentError
                 abort("❌ Invalid delay_mins: must be an integer")
               end
             else
               0
             end

def codex_cycle(iteration)
  prompt = <<~PROMPT
    Objectives: #{OBJECTIVES}
    Iteration: #{iteration}
    Current Pull Request: #{`git diff master 2>/dev/null || echo "No initial changes"`}

    Instructions:
    1. If there are changes in the PR, first check if it has already been completed; if so, do nothing.
    2. Make ONLY one incremental change.
    3. Prioritize completing main objectives.
    4. Do not overuse code comments; if the method name says it all, comments are not necessary.
    5. Do not add a blank line at the end of each file.
  PROMPT

  CodexService.new(prompt).call
end

def auto_commit
  system('git', 'add', '-A')
  # Run iacommit in an interactive shell (e.g., zsh) to load user functions
  shell = ENV.fetch('SHELL', '/bin/zsh')
  system(shell, '-i', '-c', 'iacommit <<< s')
  puts "✅ Commit made: #{`git log -1 --pretty=%B`.strip}"
  # Push changes to remote repository
  if system('git', 'push')
    puts "✅ Push successful"
    # Notify the user that commit and push have completed
    system('notify-send', 'Assistant', "✅ Push: #{`git log -1 --pretty=%B`.strip}")
  else
    puts "❌ Error pushing to remote"
    # Notify the user about the push failure
    system('notify-send', 'Assistant', '❌ Error pushing to remote')
  end
end

# Initialize iteration and trap for Ctrl-C
iteration = 1
Signal.trap("INT") do
  puts "\n🛑 Interrupt received. Exiting cleanly..."
  exit
end

# Main loop
begin
  loop do
    puts "\n🌀 Iteration ##{iteration} - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    exit_code = codex_cycle(iteration)
    if exit_code != 0
      puts "🚨 Codex process exited with code #{exit_code}. Stopping."
      break
    end
    # Detect if Codex did not produce changes: objectives completed
    if `git status --porcelain`.strip.empty?
      puts "🎉 Objectives completed; no new changes. Exiting loop..."
      break
    end
    auto_commit
    puts "⏳ Waiting #{delay_mins} minutes for next iteration... Current time: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    sleep(delay_mins * 60)
    iteration += 1
  end
rescue => e
  puts "🚨 Critical error: #{e.message}"
ensure
  puts "\n🏁 Process completed - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
  # Notify the user that the process has finished
  system('notify-send', 'Assistant', "🏁 Process completed - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}")
end
