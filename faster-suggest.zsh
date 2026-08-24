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
# Right-arrow (or $FASTER_SUGGEST_KEY / Ctrl-E) accepts the WHOLE suggestion.

# --- config -------------------------------------------------------------
typeset -g FASTER_SUGGEST_HIGHLIGHT="${FASTER_SUGGEST_HIGHLIGHT:-fg=8}"
typeset -g FASTER_SUGGEST_SCAN="${FASTER_SUGGEST_SCAN:-5000}"
typeset -g FASTER_SUGGEST_KEY="${FASTER_SUGGEST_KEY:-^E}"

# --- internal state -----------------------------------------------------
typeset -g _faster_sg_str=''
typeset -g _faster_sg_last=''
typeset -g _faster_sg_region=''   # exact region_highlight entry we own (so we never clobber others)

# Fetch the best (newest) history line that STARTS with $1.
# PURE ZSH: no fork to awk / no subshell — iterates the native $history
# associative array, bounded to the last $FASTER_SUGGEST_SCAN events.
# This removes the per-keystroke blocking fork that made the shell laggy.
_faster_sg_fetch() {
  local buf="$1" ev line keys
  _faster_sg_str=''
  # empty or contains a glob char → nothing useful to suggest
  [[ -z "$buf" || "$buf" == *[\\[\\]\\*\\?]* ]] && return
  keys=(${(Onk)history})                       # newest-first (descending event #)
  (( ${#keys} > FASTER_SUGGEST_SCAN )) && keys=(${keys[1,FASTER_SUGGEST_SCAN]})
  for ev in $keys; do                          # already newest-first
    line="$history[$ev]"
    line="${line#${line%%[![:space:]]*}}"      # trim leading whitespace
    [[ "$line" == "$buf"* ]] && { _faster_sg_str="$line"; return }
  done
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

# Right-arrow / Ctrl-E: accept the WHOLE suggestion at once (or move normally
# when there's no suggestion).
_faster_sg_accept() {
  if [[ -n "$POSTDISPLAY" ]]; then
    BUFFER="$_faster_sg_str"
    CURSOR="${#BUFFER}"
    _faster_sg_last="$BUFFER"
  else
    zle .forward-char
  fi
}

# --- wire up (idempotent: safe if sourced more than once) --------------
# Guard so a double-source (e.g. plugin-load loop + explicit source) is a no-op.
(( ${+_FASTER_SUGGEST_LOADED} )) && return
typeset -g _FASTER_SUGGEST_LOADED=1

autoload -Uz add-zle-hook-widget
zle -N _faster_sg_accept
add-zle-hook-widget line-pre-redraw _faster_sg_redraw
# Right-arrow fills the WHOLE suggestion. zsh puts the keypad in *application
# mode* on startup, so most terminals emit ESC O C (^[OC) for the arrow, not the
# normal-mode ESC [ C (^[[C). Bind BOTH so the arrow works regardless of mode.
for _faster_sg_k in '^[[C' '^[OC'; do
  bindkey "$_faster_sg_k" _faster_sg_accept
done
bindkey "$FASTER_SUGGEST_KEY" _faster_sg_accept
unset _faster_sg_k
