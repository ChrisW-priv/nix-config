PROMPT=$'%F{green}%n@%m%F{white}:%F{blue}%~\n%F{white} > '

setopt nomatch extendedglob
bindkey '^I' expand-or-complete
bindkey '^N' autosuggest-accept
bindkey -s '^F' 'tmux-sessionizer\n'
bindkey -s '^B' 'branch-sessionizer\n'

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh"

(( $+commands[go-task] )) && eval "$(go-task --completion zsh)"
(( $+commands[register-python-argcomplete] )) && eval "$(register-python-argcomplete cz)"
