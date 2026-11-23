{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    includes = [
      { condition = "gitdir:~/projects/"; path = "~/.config/git/identities/personal-github.gitconfig"; }
      { condition = "gitdir:~/work/girl/"; path = "~/.config/git/identities/girl.gitconfig"; }
      { condition = "gitdir:~/work/axpl/"; path = "~/.config/git/identities/axpl.gitconfig"; }
      { condition = "gitdir:~/work/priv_gitlab/"; path = "~/.config/git/identities/private-gitlab.gitconfig"; }
    ];

    settings = {
      user = {
        name = "Krzysztof Watras";
        email = "chris.watras@gmail.com";
      };
      pull.rebase = true;
      push = {
        default = "current";
        autoSetupRemote = true;
      };
      init.defaultBranch = "main";
      credential = {
        "https://github.com".helper = [ "" "!${pkgs.gh}/bin/gh auth git-credential" ];
        "https://gist.github.com".helper = [ "" "!${pkgs.gh}/bin/gh auth git-credential" ];
      };
      alias = {
        main = "checkout main";
        nb = "checkout -b";
        cb = "checkout";
        wta = "!f() { git fetch origin && git worktree add -b $1 ./.worktree/$1 origin/$1 2>/dev/null || git worktree add -b $1 ./.worktree/$1; }; f";
        wtr = "!f() { git worktree remove $1; git branch -d $1; }; f";
        rs = "restore --staged";
      };
    };
  };

  home.packages = [ pkgs.gh ];

  xdg.configFile = {
    "git/identities/personal-github.gitconfig".text = builtins.readFile ./identities/personal-github.gitconfig;
    "git/identities/girl.gitconfig".text = builtins.readFile ./identities/girl.gitconfig;
    "git/identities/axpl.gitconfig".text = builtins.readFile ./identities/axpl.gitconfig;
    "git/identities/private-gitlab.gitconfig".text = builtins.readFile ./identities/private-gitlab.gitconfig;
  };
}
