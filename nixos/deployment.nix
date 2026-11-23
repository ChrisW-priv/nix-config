{ config, pkgs, ... }:
{
  imports = [ ./tailscale.nix ];

  networking.hostName = "deployment";
  # The NixOS firewall blocks unsolicited incoming traffic except SSH, which
  # opens its own port below. Outgoing connections remain permitted.
  networking.firewall.enable = true;
  networking.useDHCP = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  environment.systemPackages = [ pkgs.home-manager ];

  users.users.deploy = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    # Add an authorized SSH public key here (or via a private host module)
    # before deploying. Do not put private keys or passwords in the Nix store.
    # openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];
  };

  assertions = [
    {
      assertion = config.users.users.deploy.openssh.authorizedKeys.keys != [ ]
        || config.users.users.deploy.openssh.authorizedKeys.keyFiles != [ ];
      message = "Provide a public SSH key for the deploy user before building the VPS configuration.";
    }
  ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Only for new installations. Existing systems must preserve their original
  # system.stateVersion when adopting this flake.
  system.stateVersion = "25.11";

  # Import this VPS's generated hardware-configuration.nix and add its
  # provider-specific boot, filesystem and network settings before installing.
}
