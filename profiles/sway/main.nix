{ pkgs, lib, config, profile, ... }:
let
  browserExecutable = "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/bin/librewolf";
  screenshot = pkgs.writeShellApplication {
    name = "region-to-clipboard";
    runtimeInputs = with pkgs; [ grim slurp wl-clipboard ];
    text = ''
      geometry=$(slurp) || exit 0
      [[ -n "$geometry" ]] || exit 0
      grim -g "$geometry" - | wl-copy --type image/png
    '';
  };
  displayExpand = pkgs.writeShellApplication {
    name = "display-expand";
    runtimeInputs = with pkgs; [ jq wlr-randr ];
    text = ''
      # Reset manually arranged outputs to a horizontal line. Use the current
      # modes rather than assuming all connected monitors have the same size.
      x=0
      while IFS=$'\t' read -r name width scale; do
        [[ -n "$name" ]] || continue
        wlr-randr --output "$name" --on --pos "''${x},0"
        x=$((x + (width * 100 / scale)))
      done < <(wlr-randr --json | jq -r '.[] | select(.enabled) | [.name, (.current_mode.width|tostring), ((.scale * 100)|round|tostring)] | @tsv')
    '';
  };
  # The display manager starts this via the stable Home Manager profile link.
  # Source HM's session variables so a graphical login gets the same PATH,
  # browser and XDG defaults as an interactive shell.
  startSway = pkgs.writeShellScriptBin "start-nix-sway" ''
    hmProfile="$HOME/.local/state/nix/profiles/home-manager/home-path"
    if [ ! -r "$hmProfile/etc/profile.d/hm-session-vars.sh" ]; then
      echo 'Activate the Home Manager Sway profile before logging in.' >&2
      exit 1
    fi
    export TERM="''${TERM:-xterm-256color}"
    . "$hmProfile/etc/profile.d/hm-session-vars.sh"
    export PATH="$hmProfile/bin:$PATH"
    export XDG_DATA_DIRS="$hmProfile/share:''${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    export XDG_CURRENT_DESKTOP=sway XDG_SESSION_TYPE=wayland
    ${lib.optionalString (profile == "manjaro") ''
      # Nix Mesa needs its own EGL/GBM vendor modules on this non-NixOS host.
      export __EGL_VENDOR_LIBRARY_FILENAMES="${pkgs.mesa}/share/glvnd/egl_vendor.d/50_mesa.json"
      export GBM_BACKENDS_PATH="${pkgs.mesa}/lib/gbm"
    ''}
    exec ${pkgs.dbus}/bin/dbus-run-session -- ${pkgs.sway}/bin/sway
  '';
  launcher = pkgs.writeShellApplication {
    name = "desktop-launcher";
    runtimeInputs = [ pkgs.fuzzel ];
    text = ''exec fuzzel'';
  };
  browserWorkspaceOne = pkgs.writeShellApplication {
    name = "browser-workspace-one";
    runtimeInputs = [ pkgs.sway pkgs.jq pkgs.util-linux ];
    text = ''exec ${pkgs.bash}/bin/bash ${./browser-workspace-one.sh} ${browserExecutable}'';
  };
  terminalWorkspaceTwo = pkgs.writeShellApplication {
    name = "terminal-workspace-two";
    runtimeInputs = with pkgs; [ sway jq util-linux coreutils ];
    text = ''
      # Serialize repeated keypresses until Kitty's window actually appears.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/terminal-workspace-two-$UID.lock"
      flock -w 15 9 || exit 0
      find_kitty() {
        swaymsg -t get_tree | jq -r '[.. | objects | select(.app_id? == "kitty" or .window_properties.class? == "kitty") | .id][0] // empty'
      }
      swaymsg 'workspace number 2' >/dev/null
      id=$(find_kitty)
      if [[ -n "$id" ]]; then
        swaymsg "[con_id=$id] move container to workspace number 2; [con_id=$id] focus" >/dev/null
        exit 0
      fi
      swaymsg exec "${pkgs.kitty}/bin/kitty" >/dev/null
      for _ in $(seq 1 80); do
        id=$(find_kitty)
        if [[ -n "$id" ]]; then
          swaymsg "[con_id=$id] focus" >/dev/null
          exit 0
        fi
        sleep 0.15
      done
      echo 'Kitty did not open a window on workspace 2.' >&2
      exit 1
    '';
  };
in
{
  home.packages = with pkgs; [
    sway swayidle swaybg waybar startSway
    kitty yazi xfce.thunar xfce.thunar-volman
    gimp mpv kdePackages.kdenlive obs-studio
    grim slurp wl-clipboard wdisplays wlr-randr wl-mirror
    xwayland xdg-utils xdg-desktop-portal-wlr xdg-desktop-portal-gtk
    bluez blueman pavucontrol brightnessctl
    playerctl pass podman
    jq procps util-linux
    screenshot displayExpand launcher terminalWorkspaceTwo browserWorkspaceOne
  ];

  # Desktop file associations for the activated Sway session.
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "librewolf.desktop";
      "x-scheme-handler/https" = "librewolf.desktop";
      "text/html" = "librewolf.desktop";
      "application/xhtml+xml" = "librewolf.desktop";
      "application/pdf" = "librewolf-viewer.desktop";
      "image/png" = "librewolf-viewer.desktop";
      "image/jpeg" = "librewolf-viewer.desktop";
      "image/gif" = "librewolf-viewer.desktop";
      "image/webp" = "librewolf-viewer.desktop";
      "image/avif" = "librewolf-viewer.desktop";
      "image/bmp" = "librewolf-viewer.desktop";
      "image/svg+xml" = "librewolf-viewer.desktop";
      "image/x-icon" = "librewolf-viewer.desktop";
      "text/plain" = "vim-kitty.desktop";
      "text/markdown" = "vim-kitty.desktop";
      "inode/directory" = "thunar.desktop";
      "audio/mpeg" = "mpv.desktop";
      "audio/mp4" = "mpv.desktop";
      "audio/ogg" = "mpv.desktop";
      "audio/flac" = "mpv.desktop";
      "audio/x-wav" = "mpv.desktop";
      "audio/wav" = "mpv.desktop";
      "audio/opus" = "mpv.desktop";
      "video/mp4" = "mpv.desktop";
      "video/webm" = "mpv.desktop";
      "video/x-matroska" = "mpv.desktop";
      "video/quicktime" = "mpv.desktop";
      "video/mpeg" = "mpv.desktop";
      "video/x-msvideo" = "mpv.desktop";
      "video/ogg" = "mpv.desktop";
    };
  };

  xdg.dataFile."applications/vim-kitty.desktop".text = builtins.replaceStrings [ "@KITTY@" "@VIM@" ] [ "${pkgs.kitty}/bin/kitty" "${pkgs.vim}/bin/vim" ] (builtins.readFile ./applications/vim-kitty.desktop);
  xdg.dataFile."applications/librewolf-viewer.desktop".text = builtins.replaceStrings [ "@LIBREWOLF@" ] [ browserExecutable ] (builtins.readFile ./applications/librewolf-viewer.desktop);
  xdg.configFile."sway-mimeapps.list".source = ./sway-mimeapps.list;
  xdg.configFile."sway/shortcuts.conf".source = ./shortcuts.conf;

  # XDG_CURRENT_DESKTOP must be present in both D-Bus and systemd user activation
  # environments for portal backends and file pickers started later in the session.
  xdg.configFile."sway/config".text = builtins.replaceStrings [ "@KITTY@" "@LAUNCHER@" "@WALLPAPER@" "@DBUS_UPDATE@" "@WAYBAR@" "@CONFIG_HOME@" "@WDISPLAYS@" "@SCREENSHOT@" "@PACTL@" "@BRIGHTNESSCTL@" "@BROWSER_WORKSPACE@" "@TERMINAL_WORKSPACE@" ] [ "${pkgs.kitty}/bin/kitty" "${launcher}/bin/desktop-launcher" "${../../assets/sandworm.jpg}" "${pkgs.dbus}/bin/dbus-update-activation-environment" "${pkgs.waybar}/bin/waybar" "${config.xdg.configHome}" "${pkgs.wdisplays}/bin/wdisplays" "${screenshot}/bin/region-to-clipboard" "${pkgs.pulseaudio}/bin/pactl" "${pkgs.brightnessctl}/bin/brightnessctl" "${browserWorkspaceOne}/bin/browser-workspace-one" "${terminalWorkspaceTwo}/bin/terminal-workspace-two" ] (builtins.readFile ./config);
}
