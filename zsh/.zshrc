# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-${HOME:?}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-${HOME:?}/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Set up the prompt

# autoload -Uz promptinit
# promptinit
# prompt adam1

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# Use modern completion system
#autoload -Uz compinit
#compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

source "${HOME:?}/git/antigen.zsh"

# Load the oh-my-zsh's library
antigen use oh-my-zsh

# Bundles
antigen bundle git
antigen bundle command-not-found
antigen bundle autojump

antigen bundle Tarrasch/zsh-autoenv

# Syntax highlighting bundle
antigen bundle zsh-users/zsh-syntax-highlighting
antigen bundle zsh-users/zsh-autosuggestions

# Load the theme
antigen theme romkatv/powerlevel10k

# Apply antigen configs
antigen apply

[[ -s "${HOME:?}/.autojump/etc/profile.d/autojump.sh" ]] && source "${HOME:?}/.autojump/etc/profile.d/autojump.sh" || :
autoload -U compinit && compinit -u

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Aliases
alias a="j" # Autojump alias: ex "a gdb"

# exporting variables
export ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=cyan"

# Add "scripts" dir to PATH
export PATH="${HOME:?}/scripts:${PATH}"

[[ ! -s "${HOME:?}/.zshrc_ext" ]] || source "${HOME:?}/.zshrc_ext"
fpath+=${ZDOTDIR:-~}/.zsh_functions
