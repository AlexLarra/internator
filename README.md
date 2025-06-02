 # Becario

 Becario is a Ruby-based CLI tool that automates iterative pull request improvements using OpenAI's Codex. It cycles through objectives, makes incremental changes, commits via your shell functions, and optionally waits between iterations.

 ## Requirements

 - Ruby (>= 2.5)
 - [Codex CLI](https://github.com/openai/codex) installed and in your PATH
- Shell function `iacommit()` available in your shell environment (e.g., in your `.zshrc` or `.bashrc`). See https://github.com/AlexLarra/dotfiles/blob/master/sh/sh_functions for reference.
 - Environment variable `OPENAI_API_KEY` set to your OpenAI API key
 - If you use tmux, ensure `OPENAI_API_KEY` is forwarded into tmux sessions. Add the following to your `~/.tmux.conf`, or copy lines 5–8 from https://github.com/AlexLarra/dotfiles/blob/283b3a3095994fbb2407338fd8993d640cdd1405/code/tmux/.tmux.conf#L5-L8:

   ```tmux
   # Ensure OPENAI_API_KEY is passed into tmux sessions if you use it.
   set -g update-environment "OPENAI_API_KEY"
   set-environment -g OPENAI_API_KEY "#{ENV:OPENAI_API_KEY}"
   ```

 ## Installation

```bash
gem install becario
```

Alternatively, to install from source:
```bash
git clone https://github.com/your-username/becario.git
cd becario
gem build becario.gemspec
gem install becario-0.1.0.gem
```

 ## Usage

Run the `becario` command:

```bash
becario "<PR Objectives>" [delay_mins]
```

 - `<PR Objectives>`: Description of what the pull request should achieve.
 - `[delay_mins]`: (Optional) Minutes to wait between iterations (default: 0).

Example:
```bash
becario "Refactor authentication flow and add tests" 10
```

 ## Contributing

 Feel free to open issues or submit pull requests.
