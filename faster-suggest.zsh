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
typeset -g _faster_sg_region=''   # exact region_highlight entry we own (so we never clobber others)

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
# We NEVER clobber region_highlight as a whole — fast-syntax-highlighting (and
# zsh-syntax-highlighting) paint the command line into that same shared array.
# We only remove the one entry we own (tracked in _faster_sg_region) and append
# our own, so fsh's colors survive untouched.
_faster_sg_redraw() {
  local buf="$BUFFER" rest len entry
  # drop only our previous highlight entry, leave everything else intact
  if [[ -n "$_faster_sg_region" ]]; then
    region_highlight=("${(@)region_highlight:#$_faster_sg_region}")
    _faster_sg_region=''
  fi
  if [[ "$buf" != "$_faster_sg_last" ]]; then
    _faster_sg_last="$buf"
    _faster_sg_fetch "$buf"
  fi
  if [[ -n "$_faster_sg_str" && "$_faster_sg_str" != "$buf" ]]; then
    rest="${_faster_sg_str#$buf}"
    POSTDISPLAY="$rest"
    len="${#BUFFER}"
    entry="$len $((len + ${#rest})) $FASTER_SUGGEST_HIGHLIGHT"
    region_highlight+=("$entry")
    _faster_sg_region="$entry"
  else
    POSTDISPLAY=''
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

# --- wire up (idempotent: safe if sourced more than once) --------------
# Guard so a double-source (e.g. plugin-load loop + explicit source) is a no-op.
(( ${+_FASTER_SUGGEST_LOADED} )) && return
typeset -g _FASTER_SUGGEST_LOADED=1

autoload -Uz add-zle-hook-widget
zle -N _faster_sg_forward
zle -N _faster_sg_accept
add-zle-hook-widget line-pre-redraw _faster_sg_redraw
# Right-arrow accepts one char at a time. zsh puts the keypad in *application
# mode* on startup, so most terminals emit ESC O C (^[OC) for the arrow, not the
# normal-mode ESC [ C (^[[C). Bind BOTH so the arrow works regardless of mode.
for _faster_sg_k in '^[[C' '^[OC'; do
  bindkey "$_faster_sg_k" _faster_sg_forward
done
bindkey "$FASTER_SUGGEST_KEY" _faster_sg_accept
unset _faster_sg_k
