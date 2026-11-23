{ pkgs, ... }:
{
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    defaultKeymap = "viins";

    history = {
      path = "$HOME/.zhistory";
      size = 2000;
      save = 2000;
      append = true;
      ignoreAllDups = true;
    };

    shellAliases = {
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
      python = "python3";
      py = "python3";
      open = "gio open";
      cl = "clear";
      gdb = "gdb -q";
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";
      gc = "git commit -m";
      ga = "git add";
      gs = "git status";
      ta = "tmux attach -t";
      tn = "tmux new";
      tls = "tmux list-sessions";
      tk = "tmux kill-session -t";
      hg = "history | grep";
      nv = "nvim .";
      venv = "source venv/bin/activate";
      ".venv" = "source .venv/bin/activate";
      ls = "ls --color=auto";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
      t = "go-task";
      task = "go-task";
    };

    initContent = builtins.readFile ./init.zsh;
  };

  home.packages = [ pkgs.go-task ];
}
