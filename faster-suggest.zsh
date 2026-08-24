# faster-suggest.zsh
# Lean history autosuggest for zsh — a lighter, faster replacement for
# zsh-users/zsh-autosuggestions. No fpath pollution, no widget wrapping,
# bounded recency scan. Source it from your .zshrc.
#
# Config (override before sourcing):
#   FASTER_SUGGEST_HIGHLIGHT  ghost-text color style   (default: fg=8)
#   FASTER_SUGGEST_SCAN       how many recent events to scan (default: 5000)
#   FASTER_SUGGEST_KEY        whole-suggestion accept key (default: ^E)
#
# Right-arrow accepts the suggestion one char at a time (like upstream).
# The whole suggestion is accepted with $FASTER_SUGGEST_KEY (Ctrl-E).

# --- config -------------------------------------------------------------
typeset -g FASTER_SUGGEST_HIGHLIGHT="${FASTER_SUGGEST_HIGHLIGHT:-fg=8}"
typeset -g FASTER_SUGGEST_SCAN="${FASTER_SUGGEST_SCAN:-5000}"
typeset -g FASTER_SUGGEST_KEY="${FASTER_SUGGEST_KEY:-^E}"

# --- internal state -----------------------------------------------------
typeset -g _faster_sg_str=''
typeset -g _faster_sg_last=''

# Fetch the best (newest) history line that STARTS with $1.
_faster_sg_fetch() {
  local buf="$1" cand
  # empty or contains a glob/blank → nothing useful to suggest
  [[ -z "$buf" || "$buf" == *[\[\]\*\?]* ]] && { _faster_sg_str=''; return }
  # newest-first, last N events, prefix match; trim leading spaces, take first hit
  cand=$(fc -l -r -n -"$FASTER_SUGGEST_SCAN" 2>/dev/null \
    | awk -v p="$buf" '{ sub(/^[ \t]+/, ""); if ($0 ~ "^" p) { print; exit } }')
  _faster_sg_str="$cand"
}

# Repaint ghost text after every redraw where the buffer changed.
_faster_sg_redraw() {
  local buf="$BUFFER" rest len
  if [[ "$buf" != "$_faster_sg_last" ]]; then
    _faster_sg_last="$buf"
    _faster_sg_fetch "$buf"
  fi
  if [[ -n "$_faster_sg_str" && "$_faster_sg_str" != "$buf" ]]; then
    rest="${_faster_sg_str#$buf}"
    POSTDISPLAY="$rest"
    len="${#BUFFER}"
    region_highlight=("$len $((len + ${#rest})) $FASTER_SUGGEST_HIGHLIGHT")
  else
    POSTDISPLAY=''
    region_highlight=()
  fi
}

# Right-arrow: accept one char of the suggestion (or move normally).
_faster_sg_forward() {
  if [[ -n "$POSTDISPLAY" ]]; then
    BUFFER+="${POSTDISPLAY:0:1}"
    CURSOR="${#BUFFER}"
    _faster_sg_last="$BUFFER"
    _faster_sg_fetch "$BUFFER"
  else
    zle .forward-char
  fi
}

# Accept the whole suggestion at once.
_faster_sg_accept() {
  if [[ -n "$POSTDISPLAY" ]]; then
    BUFFER="$_faster_sg_str"
    CURSOR="${#BUFFER}"
  fi
}

# --- wire up ------------------------------------------------------------
autoload -Uz add-zle-hook-widget
zle -N _faster_sg_forward
zle -N _faster_sg_accept
add-zle-hook-widget line-pre-redraw _faster_sg_redraw
bindkey '^[[C' _faster_sg_forward
bindkey "$FASTER_SUGGEST_KEY" _faster_sg_accept
