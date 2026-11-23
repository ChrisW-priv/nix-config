{
  description = "Workstation and deployment Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    # The 25.11 LibreWolf is marked insecure/unmaintained. This newer pin
    # also supplies Manjaro's NetworkManager client.
    browser-nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, browser-nixpkgs, home-manager, ... }:
    let
      mkPkgs = system: import nixpkgs { inherit system; config.allowUnfree = true; };
      desktopPkgs = import browser-nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
      mkHome = { system, profile, setup, username ? "chris" }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = mkPkgs system;
          extraSpecialArgs = {
            inherit profile setup username;
          } // nixpkgs.lib.optionalAttrs (setup == "workstation" && system == "x86_64-linux") {
            browserPkgs = desktopPkgs;
            networkmanagerPkg = if profile == "manjaro" then desktopPkgs.networkmanager else (mkPkgs system).networkmanager;
          };
          modules = [ ./main.nix ];
        };
    in
    {
      # System configurations are intentionally hardware-agnostic. Add each
      # machine's generated hardware configuration before installing it.
      nixosConfigurations = {
        workstation = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./nixos/workstation.nix ];
        };
        deployment = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./nixos/deployment.nix ];
        };
      };

      homeConfigurations = {
        # Default workstation: Manjaro with Sway.
        workstation = mkHome { system = "x86_64-linux"; profile = "manjaro"; setup = "workstation"; };
        # NixOS workstation; PAM must be enabled in the NixOS system.
        workstation-nixos = mkHome { system = "x86_64-linux"; profile = "nixos"; setup = "workstation"; };
        # Terminal-only macOS workstation.
        workstation-darwin = mkHome { system = "aarch64-darwin"; profile = "darwin"; setup = "workstation"; };
        # Headless Linux user environment (no browser or desktop).
        deploy = mkHome { system = "x86_64-linux"; profile = "nixos"; setup = "deployment"; username = "deploy"; };
      };
    };
}
