# An advanced mod demonstrating dependencies, host restrictions,
# priorities, helpers, and conditional logic.

use :basic             # Require the 'basic' mod to be installed first
hosts :workstation     # Only run on the 'workstation' host
priority :late         # Run after normal-priority mods

# Define a reusable helper that dependent mods can call
helper :greet do |name|
  note "Hello from advanced mod, #{name}!"
end

up do
  mkdir_p '~/.config/advanced'

  # Use host? to branch on hostname
  if host?(:workstation)
    install_brew 'jq'
  end

  # Use update? to detect upgrade mode (./dot up -u)
  if update?
    note 'Running in update mode'
  end

  # Symlink a config directory
  symlink './dot_config', '~/.config/advanced/config'

  # Call a helper defined by a dependency
  # helpers.some_helper_from_basic

  # Copy a file (only updates if content differs)
  # cp './defaults.conf', '~/.config/advanced/defaults.conf'
end

down do
  rm_rf '~/.config/advanced'
  remove_brew 'jq'
end
