{ pkgs, ... }:
{
  # Vaults and application state remain writable in the user's home directory.
  home.packages = [ pkgs.obsidian ];
}
