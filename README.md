# dot

A modular dotfiles framework for macOS. Organize your system configuration into
self-contained, dependency-aware modules ("mods") with a simple Ruby DSL.

## Features

- **Modular** — each mod is a self-contained directory with its own config files
- **Dependency resolution** — mods declare dependencies; topological sort ensures correct order
- **Host-aware** — restrict mods to specific machines in a multi-host setup
- **Idempotent** — safe to run repeatedly; checks state before acting
- **Reversible** — every `up` has a corresponding `down` for clean removal
- **Testable** — mods can define test blocks to verify correct installation
- **Helper system** — define reusable functions that dependent mods can call

## Requirements

- macOS
- Ruby with Bundler (included with macOS or via Homebrew)
- [Homebrew](https://brew.sh)
- [gum](https://github.com/charmbracelet/gum) (installed automatically on first run)

On first run, dot automatically installs the Ruby gems it needs (`colorize`,
`pry`, `clamp`) via Bundler inline.

## Getting Started

dot is the framework — your dotfiles live in their own repository that you
create. Download the `dot` script into your dotfiles directory and start
writing mods.

### Creating Your Dotfiles

Create your own dotfiles repository and download the `dot` script into it:

```bash
mkdir -p ~/Dotfiles/mods
cd ~/Dotfiles
git init

# Download the dot script
curl -fsSL https://raw.githubusercontent.com/sudoremo/dot/master/dot -o dot
chmod +x dot

# Add a .gitignore
echo '/switches/*' > .gitignore
echo '!/switches/.gitkeep' >> .gitignore
mkdir -p switches && touch switches/.gitkeep

# Set up this machine
./dot setup my-laptop
```

Now write your first mod. Create `mods/git/mod.rb`:

```ruby
up do
  install_brew 'git'
  symlink './dot_gitconfig', '~/.gitconfig'
end

down do
  rm '~/.gitconfig'
end
```

Run it, then commit and push your dotfiles to a repository of your choice:

```bash
./dot up git
git add -A && git commit -m "Initial dotfiles"
git remote add origin <your-repo-url>
git push -u origin master
```

### Installing on a New or Reinstalled Machine

Since `dot` is committed in your dotfiles repo, setting up a new machine is
just a clone away:

```bash
git clone <your-dotfiles-repo-url> ~/Dotfiles
cd ~/Dotfiles
./dot setup my-desktop
./dot up
```

### Updating dot

To update to the latest version, re-download the script:

```bash
curl -fsSL https://raw.githubusercontent.com/sudoremo/dot/master/dot -o ~/Dotfiles/dot
```

Alternatively, you can add dot as a
[git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) for
version-pinned updates. Create a wrapper script that sets `DOT_DIR` and
auto-initializes the submodule:

```bash
git submodule add https://github.com/sudoremo/dot.git vendor/dot
```

Then replace your `dot` script with a wrapper:

```bash
#!/bin/bash
set -euo pipefail

DOT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOT_BIN="$DOT_DIR/vendor/dot/dot"

if [ ! -f "$DOT_BIN" ]; then
  echo "Dot framework not found. Initializing submodule..."
  git -C "$DOT_DIR" submodule update --init vendor/dot
fi

export DOT_DIR
exec "$DOT_BIN" "$@"
```

The `DOT_DIR` variable tells the framework where your `mods/` and `switches/`
directories live. If not set, the framework falls back to `$0`'s parent
directory. The wrapper auto-initializes the submodule on first run, so
`git clone --recursive` is not required.

To update the framework later:

```bash
git submodule update --remote vendor/dot
```

### Running `dot` from Anywhere

By default, you run `./dot` from your dotfiles directory. To make it available
globally, make it a mod (see [The `.d` Pattern](#the-d-pattern) below):

```ruby
# mods/dot/mod.rb
use :shell

up do
  symlink './dot_profile.d.sh', '~/.profile.d/50-dot.sh'
end

down do
  rm '~/.profile.d/50-dot.sh'
end
```

```bash
# mods/dot/dot_profile.d.sh
alias dot="$HOME/Dotfiles/dot"
```

### Shell Completion

Enable tab completion for commands and mod names:

**Bash** (add to `~/.bashrc`):
```bash
eval "$(dot completion bash)"
```

**Zsh** (add to `~/.zshrc`):
```bash
eval "$(dot completion zsh)"
```

**Fish**:
```bash
dot completion fish > ~/.config/fish/completions/dot.fish
```

### Usage

```bash
./dot setup <hostname>         # One-time setup: sets system hostname, creates switches/
./dot up                       # Install all mods
./dot up git nvim              # Install specific mods (with dependencies)
./dot up -u                    # Update/upgrade packages
./dot up -t                    # Install and run tests
./dot down nvim                # Remove a specific mod
./dot down                     # Remove ALL mods (use with caution)
./dot list                     # List all mods
./dot test                     # Run tests
./dot test nvim --skip-deps    # Run tests without dependency tests
./dot git status               # Run git commands in the dotfiles directory
./dot completion bash          # Generate shell completion script
```

## Directory Structure

Your dotfiles repository will look something like this:

```
~/Dotfiles/                    # Your own repo
├── dot                        # Wrapper script (or downloaded framework)
├── switches/                  # Runtime state (gitignored)
│   ├── hostname               # Current machine hostname
│   └── set-up                 # Setup completion flag
└── mods/
    ├── shell/
    │   ├── mod.rb
    │   ├── dot_profile        # → ~/.profile (sources ~/.profile.d/*.sh)
    │   └── dot_profile.d/
    │       └── 00-base.sh     # → ~/.profile.d/00-base.sh
    ├── ruby/
    │   ├── mod.rb
    │   └── dot_profile.d.sh   # → ~/.profile.d/50-ruby.sh
    ├── git/
    │   ├── mod.rb
    │   └── dot_gitconfig      # → ~/.gitconfig
    └── ...
```

## Writing Mods

Each mod lives in `mods/<name>/` and must contain a `mod.rb` file. Config files
are stored alongside it, typically prefixed with `dot_`.

### Basic Mod

```ruby
up do
  install_brew 'ripgrep'
  symlink './dot_rgrc', '~/.rgrc'
end

down do
  remove_brew 'ripgrep'
  rm '~/.rgrc'
end
```

### Full-Featured Mod

```ruby
use :shell                    # Depend on another mod
hosts :workstation, :laptop   # Only run on these hosts
priority :early               # Run before normal-priority mods

# Define a helper that dependent mods can call
helper :configure_shell do |shell_name|
  run "chsh -s $(which #{shell_name})"
end

up do
  install_brew 'zsh'
  install_cask 'iterm2'
  symlink './dot_zshrc', '~/.zshrc'
  mkdir_p '~/.config/zsh'

  if host?(:workstation)
    install_brew 'tmux'
  end

  if update?
    note 'Running in upgrade mode'
  end
end

down do
  remove_cask 'iterm2'
  remove_brew 'zsh'
  rm '~/.zshrc'
  rm_rf '~/.config/zsh'
end

test do
  raise 'zsh not found' unless file?('/opt/homebrew/bin/zsh')
  raise '.zshrc not linked' unless symlink?('~/.zshrc')
end
```

## DSL Reference

### Mod Metadata

| Method | Description |
|---|---|
| `use :mod_name` | Declare a dependency on another mod |
| `hosts :host1, :host2` | Restrict mod to specific hostnames |
| `priority :level` | Set execution order: `:first`, `:early`, `:normal` (default), `:late`, `:last`, or an integer |
| `on_demand` | Skip mod during `./dot up` unless explicitly requested (e.g. `./dot up my_mod`) |
| `helper :name do ... end` | Define a reusable helper callable by dependent mods |

### Blocks

| Block | Description |
|---|---|
| `up do ... end` | Installation/configuration logic |
| `down do ... end` | Removal/cleanup logic (reverse of `up`) |
| `test do ... end` | Verification logic; raise an exception to signal failure |

### DSL Methods (available in `up`, `down`, `test` blocks)

#### Package Management

| Method | Description |
|---|---|
| `install_brew 'package'` | Install a Homebrew formula |
| `remove_brew 'package'` | Remove a Homebrew formula |
| `install_cask 'app'` | Install a Homebrew cask |
| `remove_cask 'app'` | Remove a Homebrew cask |
| `install_gem 'gem'` | Install a Ruby gem |
| `install_pip 'package'` | Install a pip package |
| `install_mas 123, 'App Name'` | Install from the Mac App Store (requires [mas](https://github.com/mas-cli/mas)) |

#### File Operations

| Method | Description |
|---|---|
| `symlink './source', '~/target'` | Create a symlink (with conflict resolution). Supports `sudo: true`. |
| `cp './source', '~/target'` | Copy a file (skips if identical). Supports `sudo: true`. |
| `mkdir_p '~/path'` | Create a directory (with parents) |
| `rm '~/path'` | Remove a file or symlink. Supports `sudo: true`. |
| `rm_rf '~/path'` | Remove a file or directory recursively. Supports `sudo: true`. |
| `chmod 0755, '~/path'` | Set file permissions |

#### Path Queries

| Method | Description |
|---|---|
| `file?('~/path')` | Check if a file exists |
| `dir?('~/path')` | Check if a directory exists |
| `symlink?('~/path')` | Check if a path is a symlink |
| `files_identical?('a', 'b')` | Compare two files by content |

#### System

| Method | Description |
|---|---|
| `run 'command'` | Execute a shell command. Supports `sudo: true`. |
| `enable_remote_login` | Enable macOS SSH access |
| `note 'text'` | Print an informational message |
| `confirm_or_abort 'question'` | Prompt for confirmation (exits on decline) |

#### Context

| Method | Description |
|---|---|
| `host?(:host1, :host2, ...)` | Check if running on any of the given hosts |
| `update?` | Check if running in update mode (`-u` flag) |
| `mod_dir` | Get the absolute path to the current mod's directory |
| `helpers` | Access helpers defined by dependencies (e.g. `helpers.my_helper(arg)`) |

### Path Resolution

- `./` paths resolve relative to the mod directory
- `~/` paths expand to the user's home directory
- Absolute paths are used as-is

### Helpers

Mods can define reusable helpers that dependent mods can call:

```ruby
# In mods/duti/mod.rb — define a helper for setting default apps
helper :set_default_app do |bundle_id, extension|
  run "duti -s #{bundle_id} #{extension} all"
end

# In mods/vscode/mod.rb — use the helper from a dependency
use :duti

up do
  install_cask 'visual-studio-code'
  helpers.set_default_app('com.microsoft.VSCode', '.rb')
  helpers.set_default_app('com.microsoft.VSCode', '.js')
end
```

Helpers are dependency-checked at runtime — a mod can only call helpers from
its declared dependencies.

## Priority System

Dependencies always take precedence: a mod's dependencies run before it,
regardless of priority. Among mods that are ready to run at the same time (all
dependencies satisfied), lower priority values run first:

| Priority | Value | Use Case |
|---|---|---|
| `:first` | 0 | Foundation mods (package managers) |
| `:early` | 25 | Core tools needed by many mods |
| `:normal` | 50 | Default — most mods |
| `:late` | 75 | Mods that configure other mods |
| `:last` | 100 | Cleanup, maintenance tasks |

You can also use integer values for fine-grained control.

## Tip: The `.d` Pattern

dot itself has no opinion on how you structure your shell configuration. However,
a pattern that works particularly well with modular dotfiles is the `.d`
approach: instead of a monolithic `~/.zshrc` or `~/.bashrc`, create a loader
script that sources fragments from a directory. Each mod can then contribute its
own shell snippet without touching shared files.

### Setting It Up

Create a `shell` mod that owns `~/.profile` and the `~/.profile.d/` directory:

```bash
# mods/shell/dot_profile
if [ -d ~/.profile.d ]; then
  for f in ~/.profile.d/*.sh; do
    [ -r "$f" ] && [ -f "$f" ] && . "$f"
  done
fi
```

```ruby
# mods/shell/mod.rb
up do
  symlink './dot_profile', '~/.profile'
  mkdir_p '~/.profile.d'
  symlink './dot_profile.d/00-base.sh', '~/.profile.d/00-base.sh'
end

down do
  rm '~/.profile'
  rm '~/.profile.d/00-base.sh'
end
```

### Adding Shell Fragments from Other Mods

Each mod contributes its own shell snippet, symlinked into `~/.profile.d/`:

```ruby
# mods/ruby/mod.rb
use :shell

up do
  install_brew 'ruby'
  symlink './dot_profile.d.sh', '~/.profile.d/50-ruby.sh'
end

down do
  rm '~/.profile.d/50-ruby.sh'
  remove_brew 'ruby'
end
```

```bash
# mods/ruby/dot_profile.d.sh
export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
export GEM_HOME="$HOME/.gem"
```

### Naming Convention

Use numeric prefixes to control load order:

| Prefix | Purpose | Example |
|---|---|---|
| `00-` | Base configuration | `00-base.sh` (locale, homebrew, core aliases) |
| `50-` | Mod-contributed config | `50-ruby.sh`, `50-rust.sh`, `50-nodejs.sh` |

### Why This Works Well with dot

- **Modular** — each mod manages its own shell config alongside its `mod.rb`
- **Clean removal** — `down` removes the fragment without touching other mods
- **No conflicts** — mods never edit shared files, they only add/remove their own symlink
- **Predictable order** — numeric prefixes guarantee load order

## Troubleshooting

**"Error: Hostname not configured"** — Run `./dot setup <hostname>` first. This
is required once per machine.

**"A symlink already exists but points elsewhere"** — dot will show the current
and expected targets and prompt for confirmation before replacing it.

## License

MIT
