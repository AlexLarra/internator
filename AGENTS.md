# Guide for AI Agents

## Project Overview

Internator is a Ruby CLI gem that automates iterative pull request improvements using the `opencode` CLI. It cycles through objectives, makes incremental changes, automatically commits and pushes each update, and optionally waits between iterations.

## Key Components

- **CLI (`lib/internator/cli.rb`)**: Main entry point handling argument parsing, git operations, and the iteration loop
- **OpencodeService (`lib/internator/opencode_service.rb`)**: Executes `opencode run` commands with proper shell escaping

## Development Guidelines

### Code Style

1. **No excessive comments**: If the method name is self-explanatory, comments are unnecessary
2. **No trailing newlines**: Treat files as if saved with Vim's `set binary` and `set noeol`
3. **Ruby conventions**: Follow standard Ruby style guidelines

## Configuration

Users can customize behavior via `~/.internator_config.yml`:

```yaml
instructions: |
  Custom instructions here...
```
