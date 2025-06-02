#!/usr/bin/env ruby
# assistant.rb
# This script automates commits using the OpenAI API.
# It requires the OPENAI_API_KEY environment variable to be set.
require_relative 'codex_service'
require 'net/http'
require 'uri'
require 'json'
require 'tempfile'

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

abort("❌ OPENAI_API_KEY not set. Please set the environment variable.") if ENV["OPENAI_API_KEY"].to_s.strip.empty?
abort("❌ 'codex' CLI is not installed or not in PATH. Please install it from https://github.com/openai/codex") unless system("which codex > /dev/null 2>&1")

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

def generate_commit_message(diff)
  api_key = ENV["OPENAI_API_KEY"]
  uri = URI("https://api.openai.com/v1/chat/completions")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  headers = {
    "Content-Type" => "application/json",
    "Authorization" => "Bearer #{api_key}"
  }
  body = {
    model: "gpt-4o-mini",
    messages: [
      { role: "system", content: "You are a helpful assistant that generates concise git commit messages." },
      { role: "user", content: "Generate a concise commit message for the following diff:\n\n#{diff}" }
    ],
    temperature: 0.3
  }
  response = http.post(uri.request_uri, JSON.generate(body), headers)
  if response.is_a?(Net::HTTPSuccess)
    json = JSON.parse(response.body)
    msg = json.dig("choices", 0, "message", "content")
    return msg.strip if msg
  end
rescue
  nil
end

def auto_commit
  system('git', 'add', '-A')
  status = `git diff --cached --name-status`
  content = `git diff --cached`
  diff = "File status:\n#{status}\n\nDiff:\n#{content}"
  commit_msg = generate_commit_message(diff) || ''
  short_msg = ''
  # Write full commit message to a temp file and commit via -F
  Tempfile.create('assistant-commit') do |file|
    file.write(commit_msg)
    file.flush
    file.close
    if system('git', 'commit', '-F', file.path)
      first_line = commit_msg.lines.first.to_s.strip
      short_msg = first_line.length > 50 ? "#{first_line[0,50]}..." : first_line
      puts "✅ Commit made: #{short_msg}"
    else
      puts "❌ Error committing"
    end
  end

  if system('git', 'push')
    puts "✅ Push successful"
    system('notify-send', 'Assistant', "✅ Push: #{short_msg}")
  else
    puts "❌ Error pushing to remote"
    system('notify-send', 'Assistant', "❌ Error pushing to remote: #{short_msg}")
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
