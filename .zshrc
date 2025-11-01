# ssh using gpg keys - before powerlevel 10K: https://unix.stackexchange.com/questions/608842/zshrc-export-gpg-tty-tty-says-not-a-tty
export GPG_TTY=$(tty)
export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
gpgconf --launch gpg-agent

# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
# plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-autocomplete)
# plugins=(git zsh-autosuggestions zsh-syntax-highlighting H-S-MW)
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)

source $ZSH/oh-my-zsh.sh
source <(fzf --zsh)

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# zsh-autosuggestions bind autocomplete to ctrl + 2
bindkey '^@' autosuggest-accept
# don't break autosuggestions 
bindkey '^I' expand-or-complete

ZSH_AUTOSUGGEST_STRATEGY=(history completion)


# Define fzf-powered history search
fzf-history-widget() {
  # show commands from history, unique, newest first
  local selected
  selected=$(fc -rl 1 | awk '{$1=""; print substr($0,2)}' | awk '!seen[$0]++' | \
             fzf --height=40% --border --ansi --prompt='History> ')
  if [[ -n $selected ]]; then
    LBUFFER=$selected
  fi
  zle redisplay
}
zle -N fzf-history-widget

# Bind Up arrow to trigger fzf-history-widget
bindkey -r '^[OA'
bindkey '^[OA' fzf-history-widget

# (Optional) keep Down arrow as-is or give it similar treatment
# bindkey '^[[B' fzf-history-widget

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
# tldr man plugin
alias ls="colorls"
alias tldr="/Users/jimfang/tldr"
alias code="code-insiders"
alias vim="nvim"
alias vi="nvim"
alias cat="bat"
alias catc="bat -p --paging=never"
alias ccat="bat -p --paging=never"
alias catt="/opt/homebrew/opt/coreutils/libexec/gnubin/cat"

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Created by `pipx` on 2024-11-16 06:11:43
export PATH=$PATH:/Users/jimfang/.local/bin

# Scala tools
# export PATH=$PATH:/Users/jimfang/.local/share/coursier/bin

# >>> scala-cli completions >>>
fpath=("/Users/jimfang/Library/Application Support/ScalaCli/completions/zsh" $fpath)
compinit
# <<< scala-cli completions <<<
export PATH="/opt/homebrew/opt/openjdk/bin:$PATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/Users/jimfang/miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/Users/jimfang/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/Users/jimfang/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/Users/jimfang/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<


# >>> mamba initialize >>>
# !! Contents within this block are managed by 'mamba shell init' !!
export MAMBA_EXE='/Users/jimfang/miniforge3/bin/mamba';
export MAMBA_ROOT_PREFIX='/Users/jimfang/miniforge3';
__mamba_setup="$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__mamba_setup"
else
    alias mamba="$MAMBA_EXE"  # Fallback on help from mamba activate
fi
unset __mamba_setup
# <<< mamba initialize <<<
export PATH="/opt/homebrew/opt/m4/bin:$PATH"
# alias gm4="$(which m4)"
export PATH="/opt/homebrew/opt/bison/bin:$PATH"
# export PATH="/opt/homebrew/bin/gmake:$PATH"
# alias make="$(which gmake)"
# alias gnumake="$(which gmake)"
# export RISCV="/opt/homebrew/bin"
# export RISCV="/opt/homebrew/Cellar/riscv-gnu-toolchain/main"
export YACC="$(which bison)"
export PATH="$(brew --prefix)/opt/make/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:$PATH"
export PATH="/opt/homebrew/bin:$PATH"
alias gcc="/opt/homebrew/Cellar/gcc/15.2.0/bin/gcc-15"
alias gmp="/opt/homebrew/Cellar/gmp/6.3.0/include/"
