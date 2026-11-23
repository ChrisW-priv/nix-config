{ pkgs, ... }:
let
  # Before Home Manager is activated, fall back to the system Sway binary.
  # Afterwards use its launcher, which sources the HM session environment.
  swaySession = pkgs.writeShellScript "workstation-sway-session" ''
    hmSway="$HOME/.local/state/nix/profiles/home-manager/home-path/bin/start-nix-sway"
    if [ -x "$hmSway" ]; then
      exec "$hmSway"
    fi
    exec ${pkgs.dbus}/bin/dbus-run-session -- ${pkgs.sway}/bin/sway
  '';
in
{
  imports = [ ./tailscale.nix ];

  networking.hostName = "workstation";
  networking.networkmanager.enable = true;
  # NixOS's stateful firewall blocks unsolicited incoming traffic and permits
  # outbound traffic. No SSH server or public Tailscale UDP port is opened.
  networking.firewall = {
    enable = true;
    allowPing = false;
  };
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [ pkgs.home-manager ];

  users.users.chris = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
  };
  programs.zsh.enable = true;

  services.openssh.enable = false;
  programs.sway.enable = true;
  security.pam.services.swaylock = { };
  services.greetd = {
    enable = true;
    settings.default_session.command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd ${swaySession}";
  };

  # Only for new installations. Existing systems must preserve their original
  # system.stateVersion when adopting this flake.
  system.stateVersion = "25.11";

  # Import this machine's generated hardware-configuration.nix here before
  # installing: it supplies boot, root filesystem and hardware settings.
}
