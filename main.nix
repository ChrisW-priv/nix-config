{ pkgs, lib, config, profile, setup, username, ... }:
let
  isWorkstation = setup == "workstation";
  isSway = isWorkstation && profile != "darwin";
in
{
  # Deployment shares only the terminal essentials; workstation adds the rest.
  imports = [
    ./profiles/vim/main.nix
    ./profiles/tmux/main.nix
  ] ++ lib.optionals isWorkstation [
    ./profiles/git/main.nix
    ./profiles/zsh/main.nix
  ] ++ lib.optionals isSway [
    ./profiles/networkmanager/main.nix
    ./profiles/librewolf/main.nix
    ./profiles/obsidian/main.nix
    ./profiles/fuzzel/main.nix
    ./profiles/waybar/main.nix
    ./profiles/sway/main.nix
    ./profiles/swaylock/main.nix
  ];

  home = {
    inherit username;
    homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    stateVersion = "25.11";

    # Do not put credentials in the world-readable Nix store.
    sessionVariables = {
      EDITOR = "vim";
      VISUAL = "vim";
    } // lib.optionalAttrs isWorkstation {
      PAGER = "less";
      XDG_CONFIG_HOME = "$HOME/.config";
      XDG_DATA_HOME = "$HOME/.local/share";
      XDG_CACHE_HOME = "$HOME/.cache";
      GOPATH = "$HOME/.local/share/go";
      GOBIN = "$HOME/.local/share/go/bin";
      GOMODCACHE = "$HOME/.cache/go/mod";
      OLLAMA_API_BASE = "http://127.0.0.1:11434";
      AIDER_ATTIBUTE_AUTHOR = "false";
      AIDER_ATTIBUTE_COMMITTER = "false";
      AIDER_AUTO_COMMITS = "false";
    } // lib.optionalAttrs isSway {
      TERMINAL = "kitty";
      BROWSER = "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/bin/librewolf";
    };

    sessionPath = lib.optionals isWorkstation [
      "$HOME/.config/scripts"
      "$HOME/.local/share/go/bin"
      "$HOME/.cargo/bin"
      "$HOME/.local/bin"
      "$HOME/.local/scripts"
      "$HOME/.npm-global/bin"
      "$HOME/.local/share/gem/ruby/3.4.0/bin"
    ];

    packages = lib.optionals isWorkstation (with pkgs; [ bat fd fzf ripgrep tree ]);
  };

  programs.home-manager.enable = true;
  fonts.fontconfig.enable = isSway;
  targets.genericLinux.enable = profile == "manjaro";
  programs.zsh.shellAliases = lib.mkIf (isWorkstation && profile == "darwin") {
    open = lib.mkForce "open";
    ls = lib.mkForce "ls -G";
  };
}
