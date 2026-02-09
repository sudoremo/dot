# A basic mod that installs a package and symlinks a config file.
#
# Place your configuration files alongside mod.rb and reference them
# with './' paths. They will be resolved relative to the mod directory.

up do
  install_brew 'tree'
  symlink './dot_treerc', '~/.treerc'
end

down do
  remove_brew 'tree'
  rm '~/.treerc'
end

test do
  raise 'tree not installed' unless file?('/opt/homebrew/bin/tree') || file?('/usr/local/bin/tree')
  raise '.treerc not symlinked' unless symlink?('~/.treerc')
end
