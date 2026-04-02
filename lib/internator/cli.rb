require 'net/http'
require 'uri'
require 'json'
require 'tempfile'
require 'yaml'

module Internator
  # Command-line interface for the Internator gem
  class CLI
    # Configuration file for custom options (YAML format).
    CONFIG_FILE = File.expand_path('~/.internator_config.yml')

    def self.config
      @config ||= begin
        if File.exist?(CONFIG_FILE)
          YAML.load_file(CONFIG_FILE)
        else
          {}
        end
      rescue StandardError => e
        warn "⚠️ Could not parse config file #{CONFIG_FILE}: #{e.message}"
        {}
      end
    end

    # Load custom instructions from config or fall back to built-in defaults
    def self.instructions
      main = <<~MAIN_INSTRUCTIONS
        1. If there are changes in the PR, first check if it has already been completed; if so, do nothing.
        2. Make ONLY one incremental change.
        3. Prioritize completing main objectives.
      MAIN_INSTRUCTIONS

      # Load custom instructions from ~/.internator_config.yml or fall back to built-in defaults
      secondary =
        if config.is_a?(Hash) && config['instructions'].is_a?(String)
          config['instructions'].strip
        else
          <<~SECONDARY_INSTRUCTIONS
            1. Do not overuse code comments; if the method name says it all, comments are not necessary.
            2. Please treat files as if Vim were saving them with `set binary` and `set noeol`, i.e. do not add a final newline at the end of the file.
          SECONDARY_INSTRUCTIONS
        end

      <<~INSTRUCTIONS.chomp
        Main instructions:
        #{main}
        Secondary instructions:
        #{secondary}
      INSTRUCTIONS
    end

    def self.run(args = ARGV)
      abort "❌ 'opencode' CLI is not installed or not in PATH." unless system('which opencode > /dev/null 2>&1')

      abort '❌ OPENAI_API_KEY not set. Please set the environment variable.' if ENV['OPENAI_API_KEY'].to_s.strip.empty?

      # Parse arguments: objectives, optional delay (minutes), optional parent_branch
      abort '❌ Usage: internator "<PR Objectives>" [delay_mins] [parent_branch]' if args.empty? || args.size > 3

      objectives = args[0]
      delay_mins = 0
      parent_branch = nil
      case args.size
      when 2
        # single extra arg: integer delay or parent branch
        begin
          delay_mins = Integer(args[1])
        rescue ArgumentError
          parent_branch = args[1]
        end
      when 3
        delay_mins = begin
          Integer(args[1])
        rescue StandardError
          abort('❌ Invalid delay_mins: must be an integer')
        end
        parent_branch = args[2]
      end

      remote, default_base = git_detect_default_base&.split('/', 2)
      branch = git_current_branch

      abort '❌ Git remote is not detected.' unless remote
      abort '❌ Git default branch is not detected.' unless default_base

      if branch == default_base
        abort "❌ You are on the default branch '#{default_base}'. Please create a new branch before running Internator."
      end

      if parent_branch && !system("git rev-parse --verify --quiet #{parent_branch} > /dev/null 2>&1")
        abort "❌ Specified parent branch '#{parent_branch}' does not exist."
      end

      git_upstream(remote, branch)

      iteration = 1
      Signal.trap('INT') do
        puts "\n🛑 Interrupt received. Exiting cleanly..."
        exit
      end

      begin
        loop do
          puts "\n🌀 Iteration ##{iteration} - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"

          exit_code = codex_cycle(objectives, iteration, remote, default_base, branch, parent_branch)
          abort "🚨 Opencode process exited with code #{exit_code}. Stopping." if exit_code != 0

          abort '🎉 Objectives completed; no new changes. Exiting loop...' if `git status --porcelain`.strip.empty?

          auto_commit
          puts "⏳ Waiting #{delay_mins} minutes for next iteration... Current time: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
          sleep(delay_mins * 60)
          iteration += 1
        end
      rescue StandardError => e
        puts "🚨 Critical error: #{e.message}"
      ensure
        puts "\n🏁 Process completed - #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
      end
    end

    # Detect the repository's default branch across remotes (e.g., main, master, develop)
    def self.git_detect_default_base
      remotes = `git remote`.split("\n").reject(&:empty?)
      remotes.unshift('origin') unless remotes.include?('origin')
      remotes.each do |remote|
        # Try to resolve remote HEAD via rev-parse
        ref = `git rev-parse --abbrev-ref #{remote}/HEAD 2>/dev/null`.strip
        return ref unless ref.empty?

        # Fallback to symbolic-ref
        sym = `git symbolic-ref refs/remotes/#{remote}/HEAD 2>/dev/null`.strip
        return sym.sub('refs/remotes/', '') if sym.start_with?('refs/remotes/')
      end
      nil
    end

    def self.git_current_branch
      `git rev-parse --abbrev-ref HEAD`.strip
    end

    def self.git_upstream(remote, branch)
      upstream = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.strip

      if upstream.empty?
        # As upstream is not configured, push the current branch and set upstream to remote
        puts "🔄 No upstream configured for branch '#{branch}'. Sending to #{remote}..."
        system("git push -u #{remote} #{branch}")
        upstream = `git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null`.strip
      end

      upstream
    end

    # Executes one Codex iteration by diffing against the parent or default branch
    def self.codex_cycle(objectives, iteration, _remote, default_base, _branch, parent_branch = nil)
      # Determine base branch: user-specified parent or detected default
      base = parent_branch || default_base
      current_diff = `git diff #{base} 2>/dev/null`
      current_diff = 'No initial changes' if current_diff.strip.empty?
      prompt = <<~PROMPT
        Objectives: #{objectives}
        Iteration: #{iteration}
        Current Pull Request: #{current_diff}

        #{instructions}
      PROMPT

      OpencodeService.new(prompt).call
    end

    # Generate a concise commit message for the given diff using OpenAI
    def self.generate_commit_message(diff)
      uri = URI('https://api.openai.com/v1/chat/completions')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      headers = {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{ENV['OPENAI_API_KEY']}"
      }
      body = {
        model: 'gpt-4o-mini',
        messages: [
          { role: 'system', content: 'You are a helpful assistant that generates concise git commit messages.' },
          { role: 'user', content: "Generate a concise commit message for the following diff:\n\n#{diff}" }
        ],
        temperature: 0.3
      }
      response = http.post(uri.request_uri, JSON.generate(body), headers)
      if response.is_a?(Net::HTTPSuccess)
        json = JSON.parse(response.body)
        msg = json.dig('choices', 0, 'message', 'content')
        msg.strip if msg
      end
    rescue StandardError
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
          puts '❌ Error committing'
        end
      end

      if system('git', 'push')
        puts '✅ Push successful'
      else
        puts '❌ Error pushing to remote'
      end
    end
  end
end
