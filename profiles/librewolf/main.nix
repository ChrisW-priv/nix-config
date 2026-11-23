{ browserPkgs, config, ... }:
let
  loginOrigins = [
    "https://accounts.google.com"
  ];
  vimiumXpi = browserPkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/4717567/vimium_ff-2.4.2.xpi";
    hash = "sha256-Ex4qZ1gOeukSWrGXgRWeYUCfrEe0Qfwngqq3Y5bq0ZY=";
  };
  reflexBlockXpi = browserPkgs.fetchurl {
    url = "https://addons.mozilla.org/firefox/downloads/file/5264241/reflex_block-1.0.0.xpi";
    hash = "sha256-w8aiplq52BVdXZlql3QKOnC9J3txZwG4IrvRhlasb1U=";
  };
in
{
  programs.librewolf = {
    enable = true;
    package = browserPkgs.librewolf;

    # Cookies.Allow permits these sites to set cookies, but is no longer the
    # mechanism for exempting them from shutdown cleanup. Keep LibreWolf's
    # cookie/cache cleanup and explicitly exempt the login origins. The other
    # cleanup categories match LibreWolf's existing defaults.
    policies.Cookies.Allow = loginOrigins;
    # Install the signed AMO XPI into the writable profile once. This local
    # bootstrap works; a remote AMO URL did not install in an isolated test.
    policies.Extensions.Install = [ "${vimiumXpi}" "${reflexBlockXpi}" ];
    # Reflex Block merges these managed defaults with sites added in its
    # writable profile. Users can exempt a managed site in the add-on UI.
    policies."3rdparty".Extensions."reflexblock@watras.local".blocked = [
      "facebook.com"
      "instagram.com"
      "reddit.com"
      "youtube.com"
    ];
    # Default to the Extensions menu, not the toolbar, on first install.
    # Existing user toolbar choices remain theirs.
    policies.ExtensionSettings = {
      "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
        installation_mode = "allowed";
        default_area = "menupanel";
      };
      "reflexblock@watras.local" = {
        installation_mode = "allowed";
        default_area = "menupanel";
      };
    };
    policies.ClearOnShutdown = {
      CookiesAndStorage = true;
      Cache = true;
      BrowsingHistoryAndDownloads = false;
      FormData = false;
      SiteSettings = false;
      Exceptions = loginOrigins;
    };

    # Let LibreWolf offer to save passwords (stored in its writable profile,
    # never in Nix). This is separate from keeping Google signed in.
    settings."signon.rememberSignons" = true;
  };

  # The existing browser profile is XDG-based (~/.config/librewolf/librewolf).
  # HM's LibreWolf module writes the global overrides to ~/.librewolf; link
  # the same overrides into the XDG location as well, without touching the
  # browser's live profile, profiles.ini, cookies.sqlite or passwords.
  xdg.configFile."librewolf/librewolf/librewolf.overrides.cfg".source =
    config.home.file.".librewolf/librewolf.overrides.cfg".source;
}
