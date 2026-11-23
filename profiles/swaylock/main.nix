{ pkgs, lib, profile, ... }:
let
  locker = if profile == "manjaro" then "/usr/bin/swaylock" else "${pkgs.swaylock}/bin/swaylock";
in
{
  home.packages = lib.optionals (profile != "manjaro") [ pkgs.swaylock ];

  # Use the host PAM-linked binary on Manjaro, the Nix binary on NixOS.
  xdg.configFile."sway/lock.conf".text = builtins.replaceStrings [ "@LOCKER@" "@SWAYIDLE@" ] [ locker "${pkgs.swayidle}/bin/swayidle" ] (builtins.readFile ./lock.conf);
}
