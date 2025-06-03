require "net/http"
require "uri"
require "json"
require "tempfile"

module Internator
  # Command-line interface for the Internator gem
  class CLI
    def self.run(args = ARGV)
      unless system("which codex > /dev/null 2>&1")
        abort "❌ 'codex' CLI is not installed or not in PATH. Please install it from https://github.com/openai/codex"
      end

      if ENV["OPENAI_API_KEY"].to_s.strip.empty?
        abort "❌ OPENAI_API_KEY not set. Please set the environment variable."
      end

      if args.empty? || args.size > 2
        abort "❌ Usage: internator \"<PR Objectives>\" [delay_mins]"
      end

      objectives = args[0]
      delay_mins = if args[1]
                     Integer(args[1]) rescue abort("❌ Invalid delay_mins: must be an integer")
                   else
                     0
                   end

      iteration = 1
      Signal.trap("INT") do
        puts "\n🛑 Interrupt received. Exiting cleanly..."
        exit
      end

      begin
        loop do
          puts "\n🌀 Iteration ##{iteration} - #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
          exit_code = codex_cycle(objectives, iteration)
          if exit_code != 0
            puts "🚨 Codex process exited with code #{exit_code}. Stopping."
            break
          end

          if `git status --porcelain`.strip.empty?
            puts "🎉 Objectives completed; no new changes. Exiting loop..."
            break
          end

          auto_commit
          puts "⏳ Waiting #{delay_mins} minutes for next iteration... Current time: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
          sleep(delay_mins * 60)
          iteration += 1
        end
      rescue => e
        puts "🚨 Critical error: #{e.message}"
      ensure
        puts "\n🏁 Process completed - #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}"
      end
    end

    # Detect the repository's default branch across remotes (e.g., main, master, develop)
    def self.detect_default_base
      remotes = `git remote`.split("\n").reject(&:empty?)
      remotes.unshift('origin') unless remotes.include?('origin')
      remotes.each do |remote|
        # Try to resolve remote HEAD via rev-parse
        ref = `git rev-parse --abbrev-ref #{remote}/HEAD 2>/dev/null`.strip
        return ref unless ref.empty?
        # Fallback to symbolic-ref
        sym = `git symbolic-ref refs/remotes/#{remote}/HEAD 2>/dev/null`.strip
        if sym.start_with?('refs/remotes/')
          return sym.sub('refs/remotes/', '')
        end
      end
      nil
    end

    # Executes one Codex iteration by diffing against the appropriate base branch
    def self.codex_cycle(objectives, iteration)
      # Determine configured upstream and current branch name
      upstream = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.strip
      current_branch = `git rev-parse --abbrev-ref HEAD`.strip
      # Choose diff base:
      # 1) If upstream is tracking current branch, use remote default branch
      # 2) Else if upstream exists, diff against that
      # 3) Otherwise fallback to remote default branch or master
      if !upstream.empty? && upstream.split('/').last == current_branch
        base = detect_default_base || upstream
      elsif !upstream.empty?
        base = upstream
      else
        base = detect_default_base || 'master'
      end
      # Get the diff against the chosen base
      current_diff = `git diff #{base} 2>/dev/null`
      current_diff = "No initial changes" if current_diff.strip.empty?
      prompt = <<~PROMPT
        Objectives: #{objectives}
        Iteration: #{iteration}
        Current Pull Request: #{current_diff}

        Instructions:
        1. If there are changes in the PR, first check if it has already been completed; if so, do nothing.
        2. Make ONLY one incremental change.
        3. Prioritize completing main objectives.
        4. Do not overuse code comments; if the method name says it all, comments are not necessary.
        5. Do not add a blank line at the end of each file.
      PROMPT

      CodexService.new(prompt).call
    end

    # Generate a concise commit message for the given diff using OpenAI
    def self.generate_commit_message(diff)
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

    def self.auto_commit
      system('git', 'add', '-A')
      status = `git diff --cached --name-status`
      content = `git diff --cached`
      diff = "File status:\n#{status}\n\nDiff:\n#{content}"
      commit_msg = generate_commit_message(diff) || ''

      # Write full commit message to a temp file and commit via -F
      Tempfile.create('internator-commit') do |file|
        file.write(commit_msg)
        file.flush
        file.close
        if system('git', 'commit', '-F', file.path)
          first_line = commit_msg.lines.first.to_s.strip
          puts "✅ Commit made: #{first_line}"
        else
          puts "❌ Error committing"
        end
      end

      if system('git', 'push')
        puts "✅ Push successful"
      else
        puts "❌ Error pushing to remote"
      end
    end
  end
end
