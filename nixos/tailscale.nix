{ ... }:
{
  # Authentication is done after installation; never put an auth key in the
  # flake or Nix store. Keep the UDP listener blocked on the public interface:
  # Tailscale can fall back to outbound relay connections (DERP).
  services.tailscale = {
    enable = true;
    openFirewall = false;
  };
}
