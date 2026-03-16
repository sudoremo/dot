# LLM Instructions for dot

dot is a modular macOS dotfiles framework. Users organize system configuration
into self-contained modules ("mods") using a Ruby DSL.

## Commands

```
./dot setup <hostname>      # One-time machine setup
./dot up [mod ...]          # Install mods (-u to upgrade packages, -t to test, -s to skip)
./dot down [mod ...]        # Remove mods (-s to skip)
./dot list                  # List all mods
./dot test [mod ...]        # Run tests (--skip-deps to skip dependency tests)
./dot git <args>            # Run git in the dotfiles directory
```

## Directory Layout

```
~/Dotfiles/
├── dot                     # Framework script (or wrapper)
├── switches/               # Runtime state (gitignored)
│   ├── hostname            # Machine hostname
│   └── set-up              # Setup flag
└── mods/
    └── <name>/
        ├── mod.rb          # Required: mod definition
        └── dot_*           # Config files (symlinked to ~/)
```

## Writing Mods

Every mod is a directory under `mods/` containing a `mod.rb` file. Config files
live alongside it, conventionally prefixed with `dot_`.

### Minimal Example

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

### Mod Metadata (top-level, outside blocks)

| Method | Description |
|---|---|
| `use :mod_name` | Depend on another mod (runs it first) |
| `hosts :host1, :host2` | Restrict to specific machine hostnames |
| `priority :level` | `:first` (0), `:early` (25), `:normal` (50, default), `:late` (75), `:last` (100), or integer |
| `on_demand` | Skip during `./dot up` unless explicitly named |
| `helper :name do \|args\| ... end` | Define a reusable helper callable by dependent mods |

### Blocks

- `up do ... end` -- installation logic
- `down do ... end` -- removal logic (must fully reverse `up`)
- `test do ... end` -- verification; raise an exception to signal failure

### DSL Methods (available inside `up`, `down`, `test`)

**Package management:**
`install_brew`, `remove_brew`, `install_cask`, `remove_cask`, `install_gem`,
`install_pip`, `install_mas(id, name)`

**File operations:**
`symlink(from, to)`, `cp(from, to)`, `mkdir_p(path)`, `rm(path)`,
`rm_rf(path)`, `chmod(mode, path)` -- all support `sudo: true` where noted.

**Path queries:**
`file?(path)`, `dir?(path)`, `symlink?(path)`, `files_identical?(a, b)`

**System:**
`run(command)` (supports `sudo: true`), `enable_remote_login`,
`note(text)`, `confirm_or_abort(question)`

**Context:**
`host?(:name, ...)`, `update?`, `mod_dir`, `helpers`

### Path Resolution

- `./` -- relative to the mod directory (e.g., `./dot_gitconfig`)
- `~/` -- user home directory
- Absolute paths are used as-is

### Helpers

Define in a mod, call from dependents:

```ruby
# mods/duti/mod.rb
helper :set_default_app do |bundle_id, ext|
  run "duti -s #{bundle_id} #{ext} all"
end

# mods/vscode/mod.rb
use :duti
up do
  helpers.set_default_app('com.microsoft.VSCode', '.rb')
end
```

## Rules for Writing Mods

1. **Idempotent** -- `up` must be safe to run repeatedly. The DSL methods
   already handle this (e.g., `symlink` checks existing state, `install_brew`
   skips if already installed).
2. **Reversible** -- `down` must fully undo `up`. Remove every symlink, package,
   and directory that `up` creates.
3. **Self-contained** -- all config files belong in the mod directory. Reference
   them with `./` paths. Never place files outside the mod directory.
4. **Always symlink** -- use `symlink`, never copy, for config files. This keeps
   the repo the single source of truth.
5. **Use DSL methods** -- prefer `install_brew`, `symlink`, `rm` over raw `run`
   commands. They provide idempotency, logging, and conflict resolution.
6. **Use `sudo:` parameter** -- pass `sudo: true` to DSL methods instead of
   embedding `sudo` in `run` commands.
7. **Declare dependencies** -- use `use :mod_name` if your mod relies on another.
8. **Preserve user data** -- never delete files the user may have created outside
   of dot.

## The `.d` Pattern

A recommended pattern for shell configuration: a base `shell` mod owns
`~/.profile` which sources `~/.profile.d/*.sh`. Other mods symlink their shell
snippets into that directory with numeric prefixes for ordering (`00-` for base,
`50-` for mod-contributed).

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
