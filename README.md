# NixOS systems and Home Manager setups

## NixOS system targets

The flake exposes `nixosConfigurations.workstation` and `nixosConfigurations.deployment` (both x86_64 Linux). These are **system** configurations, distinct from the Home Manager targets below.

- `workstation` creates the `chris` user, enables NetworkManager and Sway, and offers a greetd/tuigreet login. Once Home Manager is activated, its Sway launcher is used; until then the greeter launches system Sway.
- `deployment` creates the `deploy` user, enables the OpenSSH server with key-only login and no root SSH login, and installs no desktop. It requires an authorized public key for `deploy`. This target does not configure any VPS-provider networking beyond DHCP.

Both NixOS systems enable Tailscale and NixOS's **native stateful firewall** (not UFW). Outgoing traffic is permitted. The workstation opens **no incoming service ports**, including SSH; the deployment target opens TCP 22 for public SSH. Neither opens Tailscale's public UDP port, so direct peer connections may be unavailable and Tailscale may use outbound DERP relays. The VPS provider may have an additional firewall: permit public SSH there as well before relying on remote access. These NixOS settings do not change the existing Manjaro workstation's firewall.

After switching to the NixOS system target, enroll Tailscale interactively (no auth key is stored in this repo):

- Workstation: `sudo tailscale up --shields-up --netfilter-mode=off` — it can reach other tailnet devices but will not accept tailnet connections. `netfilter-mode=off` prevents Tailscale from inserting rules that could bypass the host firewall.
- Deployment: `sudo tailscale up --netfilter-mode=off` — incoming SSH remains permitted via the NixOS firewall, including over Tailscale. Other incoming services remain blocked.

Tailscale persists these settings in its writable state across reboots. If you reset Tailscale or re-enroll, use the same flags again; authenticating with a plain `tailscale up` would restore its default netfilter behavior. Check `tailscale status` and `sudo tailscale debug prefs` after enrolling. Do not close public VPS SSH until tailnet SSH is independently confirmed working from another machine.

**Neither NixOS target is installable as-is.** Before using one, import that machine's generated `hardware-configuration.nix` into `nixos/workstation.nix` or `nixos/deployment.nix`. That file supplies the root filesystem and boot settings; also configure any VPS-specific network, disk or boot requirements. For the VPS, set `users.users.deploy.openssh.authorizedKeys.keys = [ "ssh-ed25519 ..." ];` (or `keyFiles`) in the system configuration. There is an assertion to prevent building it without a deploy key. Public keys are safe to store here; never store private keys or passwords in the repo. For a fresh desktop installation, set `chris`'s login password during installation. On an existing NixOS install, **preserve its existing `system.stateVersion`** rather than using these modules' fresh-install value (`25.11`).

After preparing the machine-specific configuration, activate the system with `sudo nixos-rebuild switch --flake .#workstation` or `sudo nixos-rebuild switch --flake .#deployment`. The NixOS targets do **not** automatically activate Home Manager: to get the workstation's LibreWolf, Waybar and personal Sway config, also run `home-manager switch --flake .#workstation-nixos` as `chris`. For the VPS's terminal tools, run `home-manager switch --flake .#deploy` as `deploy`. Home Manager does not manage SSH client settings or ssh-agent on any target; only the NixOS deployment system enables an SSH server. Don't switch a running machine to the other system target just to test it.

## Home Manager targets

Two setups share app modules under `profiles/<app>/main.nix`:

| Setup | Flake targets | Contents |
| --- | --- | --- |
| Workstation | `workstation` (Manjaro, x86_64 Linux), `workstation-nixos` (NixOS, x86_64 Linux), `workstation-darwin` (aarch64 macOS) | Terminal tools and personal configuration; Sway/LibreWolf, Obsidian and GUI apps on Linux only. |
| Deployment | `deploy` (x86_64 Linux) | Vim and tmux (with zsh for tmux panes), without a desktop, browser or personal Git/GPG/SSH client configuration. |

Workstation targets default to the `chris` user; `deploy` selects the `deploy` user and `/home/deploy`. To configure another username, change or add `username = "...";` in that target's `mkHome` call in `flake.nix` (the home directory follows automatically). The target doesn't create the user, provision a server or install an SSH daemon.

Activate on the appropriate machine with `home-manager switch --flake .#workstation` (or `.#workstation-nixos`, `.#workstation-darwin`, `.#deploy`). Do not switch a running workstation to the deployment target just to test it: switching would remove workstation-managed files from that user's Home Manager generation. Inspect without activating: `nix eval .#homeConfigurations.deploy.activationPackage.drvPath`.

Waybar's Wi-Fi controls always invoke Nix-provided `nmcli`. On Manjaro it comes from the separately locked `browser-nixpkgs` input (NetworkManager **1.58.1** in the current `flake.lock`, matching the Manjaro stable repository checked at the time); NixOS uses the main `nixpkgs` input. Home Manager exposes **only `nmcli`** in the user's profile. The upstream Nix package also contains the daemon, so it remains in the store as a dependency, but this repo does not install or run it as a service. The client version is reproducibly pinned, not automatically updated to the latest stable release.

On Manjaro, keep the host's NetworkManager system service. After activating the workstation, you may **optionally** update Manjaro's daemon through pacman (`sudo pacman -Syu`, which updates the system, including NetworkManager if a newer package is available). Compare `nmcli --version` and `pacman -Q networkmanager` first; the two repositories do not guarantee an exact version match. Restarting NetworkManager can interrupt connectivity, so do not automate a restart during Home Manager activation. On NixOS, enable `networking.networkmanager.enable = true;` in the NixOS system configuration instead.

Nix knows Linux vs. Darwin from the explicitly selected Nixpkgs `system`, so app modules can use `pkgs.stdenv.isLinux` and `pkgs.stdenv.isDarwin`. NixOS and other Linux distributions share that system value (`x86_64-linux`); pure flake evaluation cannot reliably detect the host distribution. Choose `workstation-nixos` vs. `workstation` explicitly because their Sway and Linux integration settings differ.
