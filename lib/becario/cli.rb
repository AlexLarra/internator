require "becario/codex_service"

module Becario
  # Command-line interface for the Becario gem
  class CLI
    def self.run(args = ARGV)
      unless system("which codex > /dev/null 2>&1")
        abort "❌ 'codex' CLI is not installed or not in PATH. Please install it from https://github.com/openai/codex"
      end

      if ENV["OPENAI_API_KEY"].to_s.strip.empty?
        abort "❌ OPENAI_API_KEY not set. Please set the environment variable."
      end

      if args.empty? || args.size > 2
        abort "❌ Usage: becario \"<PR Objectives>\" [delay_mins]"
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
        system("notify-send", "Assistant", "🏁 Process completed - #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}")
      end
    end

    def self.codex_cycle(objectives, iteration)
      current_diff = `git diff master 2>/dev/null`
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

    def self.auto_commit
      system("git", "add", "-A")
      shell = ENV.fetch("SHELL", "/bin/zsh")
      system(shell, "-i", "-c", "iacommit <<< s")
      puts "✅ Commit made: #{`git log -1 --pretty=%B`.strip}"
      if system("git", "push")
        puts "✅ Push successful"
        system("notify-send", "Assistant", "✅ Push: #{`git log -1 --pretty=%B`.strip}")
      else
        puts "❌ Error pushing to remote"
        system("notify-send", "Assistant", "❌ Error pushing to remote")
      end
    end
  end
end