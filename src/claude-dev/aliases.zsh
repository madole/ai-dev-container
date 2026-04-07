# Claude Dev Container aliases
alias claude-s='claude --dangerously-skip-permissions'
alias claude-dev-version='cat /usr/local/share/claude-dev/version'

# Git helpers
alias gst="git status"
alias ga="git add"
alias gph="git push origin HEAD"
alias gp="git push origin"
alias gpl="git pull origin"
alias gcm="git commit -m"
alias gco="git checkout"
alias gd="git diff"
alias gc="git commit"
alias gcl="git clone"

# Dev
alias nd="npm run dev"

# Utilities
alias ls="ls -laFhtr"
alias lt='du -sh * | sort -hr'
alias hs='history | grep'
alias cls='clear && printf "\e[3J"'
alias count='echo "Count: $(ls | wc -l)"'

# What's on this port?
wp() {
  if [[ -z $1 ]]; then
    echo "What is running on this port?"
    echo "Usage: wp <port_number>"
  else
    lsof -i :$1
  fi
}
