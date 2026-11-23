{ pkgs, networkmanagerPkg, ... }:
let
  # NetworkManager ships client and daemon in one Nix output. Expose only
  # nmcli in the user's profile; never install a system service via HM.
  nmcli = pkgs.runCommand "nmcli-${networkmanagerPkg.version}" { } ''
    mkdir -p "$out/bin"
    ln -s ${networkmanagerPkg}/bin/nmcli "$out/bin/nmcli"
  '';
in
{
  home.packages = [ nmcli ];
}
