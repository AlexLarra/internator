[![Gem Version](https://img.shields.io/gem/v/internator.svg)](https://rubygems.org/gems/internator)

# Internator

Internator is a Ruby-based CLI tool that automates iterative pull request improvements using OpenAI's Codex. It cycles through objectives, makes incremental changes, automatically commits and pushes each update, and optionally waits between iterations.

 ## Requirements

 - Ruby (>= 2.5).
 - [Codex CLI](https://github.com/openai/codex) installed (>= 0.3.0).
 - Environment variable `OPENAI_API_KEY` set to your OpenAI API key.

 ## Installation

```bash
gem install internator
```

 ## Usage

Push to Github your new empty branch and run the `internator` command:

```bash
internator "<PR Objectives>" [delay_mins]
```

 - `<PR Objectives>`: Description of what the pull request should achieve.
 - `[delay_mins]`: (Optional) Minutes to wait between iterations (default: 0).

Example:
```bash
internator "Refactor authentication flow and add tests" 10
```
For more detailed usage tips, see the [Usage Tips wiki page](https://github.com/AlexLarra/internator/wiki/Usage-tips).

## Configuration

Internator reads custom instructions from a YAML file at `~/.internator_config.yml`. The file must define an `instructions` key whose value is the instruction text. For example:

```yaml
# ~/.internator_config.yml
instructions: |
  1. Do not overuse code comments; if the method name says it all, comments are not necessary.
  2. Please treat files as if Vim were saving them with `set binary` and `set noeol`, i.e. do not add a final newline at the end of the file.
```

When present, Internator will use these instructions instead of the built-in defaults.

## Contributing

Feel free to open issues or submit pull requests.

 ## License

 Internator is released under the MIT License. See the [LICENSE](LICENSE) file for details.
