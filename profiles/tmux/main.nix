{ pkgs, lib, setup, ... }:
let
  tmux-sessionizer = pkgs.writeShellApplication {
    name = "tmux-sessionizer";
    runtimeInputs = with pkgs; [ coreutils findutils fzf tmux ]
      ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.procps ];
    text = ''
      if [[ $# -eq 1 ]]; then
        selected=$1
      else
        selected=$( (find "$HOME/projects" -mindepth 0 -maxdepth 1 -type d 2>/dev/null; find "$HOME/work" -mindepth 0 -maxdepth 2 -type d 2>/dev/null) | fzf)
      fi

      [[ -z "''${selected:-}" ]] && exit 0

      selected_name=$(basename "$selected" | tr . _)
      tmux_running=$(pgrep tmux || true)

      if [[ -z "''${TMUX:-}" && -z "$tmux_running" ]]; then
        tmux new-session -s "$selected_name" -c "$selected"
        exit 0
      fi

      if ! tmux has-session -t="$selected_name" 2>/dev/null; then
        tmux new-session -ds "$selected_name" -c "$selected"
      fi

      if [[ -z "''${TMUX:-}" ]]; then
        tmux attach -t "$selected_name"
      else
        tmux switch-client -t "$selected_name"
      fi
    '';
  };
in
{
  home.packages = lib.optionals (setup == "workstation") [ tmux-sessionizer ];

  programs.tmux = {
    enable = true;
    prefix = "C-a";
    mouse = true;
    keyMode = "vi";
    baseIndex = 1;
    terminal = "screen-256color";
    shell = "${pkgs.zsh}/bin/zsh";
    plugins = [ pkgs.tmuxPlugins.yank ];

    extraConfig = builtins.readFile ./tmux.conf
      + lib.optionalString (setup == "workstation") ''
        # Refresh the Sway socket from the attaching terminal after a Sway restart.
        set -ag update-environment SWAYSOCK
      '';
  };
}
