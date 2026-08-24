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
# Alt-right accepts one WORD at a time.

# --- config -------------------------------------------------------------
typeset -g FASTER_SUGGEST_HIGHLIGHT="${FASTER_SUGGEST_HIGHLIGHT:-fg=8}"
typeset -g FASTER_SUGGEST_SCAN="${FASTER_SUGGEST_SCAN:-5000}"
typeset -g FASTER_SUGGEST_KEY="${FASTER_SUGGEST_KEY:-^E}"

# --- internal state -----------------------------------------------------
typeset -g _faster_sg_str=''
typeset -g _faster_sg_last=''
typeset -g _faster_sg_region=''   # exact region_highlight entry we own

# Fetch the best (newest) history line that STARTS with $1.
# PURE ZSH: no fork, no subshell. Walks event numbers downward from the
# highest key in $history — O(SCAN) regardless of total HISTSIZE.
_faster_sg_fetch() {
  local buf="$1" ev line count=0 top
  _faster_sg_str=''
  # empty buffer → nothing to suggest
  [[ -z "$buf" ]] && return
  # highest event number = newest command. In interactive ZLE, HISTCMD points
  # to the current line being edited, so the last SAVED entry is HISTCMD-1.
  # Fallback to the highest $history key if HISTCMD is unset (defensive).
  top=$(( HISTCMD - 1 ))
  (( top < 1 )) && { top="${${(knO)history}[1]}"; [[ -z "$top" ]] && return }
  for (( ev = top; ev >= 1 && count < FASTER_SUGGEST_SCAN; ev-- )); do
    line="$history[$ev]"
    [[ -z "$line" ]] && continue
    (( count++ ))
    line="${line#${line%%[![:space:]]*}}"      # trim leading whitespace
    # safe prefix match: literal string removal, no glob interpretation
    [[ "${line#"$buf"}" != "$line" ]] && { _faster_sg_str="$line"; return }
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
    rest="${_faster_sg_str#"$buf"}"
    POSTDISPLAY="$rest"
    len="${#BUFFER}"
    entry="$len $((len + ${#rest})) $FASTER_SUGGEST_HIGHLIGHT"
    region_highlight+=("$entry")
    _faster_sg_region="$entry"
  else
    POSTDISPLAY=''
  fi
}

# Trigger syntax highlighting update if fast-syntax-highlighting or
# zsh-syntax-highlighting is present.
_faster_sg_rehighlight() {
  if (( $+functions[_zsh_highlight] )); then
    _zsh_highlight
  fi
}

# Accept the WHOLE suggestion at once (or move normally when no suggestion).
_faster_sg_accept() {
  if [[ -n "$POSTDISPLAY" ]]; then
    BUFFER="$_faster_sg_str"
    CURSOR="${#BUFFER}"
    POSTDISPLAY=''
    _faster_sg_last="$BUFFER"
    _faster_sg_rehighlight
  else
    zle .forward-char
  fi
}

# Accept one WORD of the suggestion (Alt-Right behavior).
_faster_sg_accept_word() {
  if [[ -n "$POSTDISPLAY" ]]; then
    local rest="$POSTDISPLAY" word
    # grab the next word: leading whitespace + non-whitespace chunk
    word="${rest%%[[:space:]]*}"
    # if word == rest (no space found), check if rest starts with spaces
    if [[ "$word" == "$rest" ]]; then
      # single word left, accept all of it
      BUFFER="$_faster_sg_str"
      CURSOR="${#BUFFER}"
      POSTDISPLAY=''
    else
      # include trailing whitespace after the word
      local grab="${rest%%[![:space:]]*}"      # leading spaces (if any)
      rest="${rest#"$grab"}"                   # strip leading spaces
      local chunk="${rest%%[[:space:]]*}"       # the word itself
      grab="${grab}${chunk}"
      # also eat trailing space so cursor lands at next word start
      rest="${rest#"$chunk"}"
      local trail="${rest%%[![:space:]]*}"
      grab="${grab}${trail}"
      BUFFER="${BUFFER}${grab}"
      CURSOR="${#BUFFER}"
      POSTDISPLAY="${_faster_sg_str#"$BUFFER"}"
    fi
    _faster_sg_last="$BUFFER"
    _faster_sg_rehighlight
  else
    zle .forward-word
  fi
}

# Clear ghost text on Enter so it doesn't flash on the new prompt.
_faster_sg_finish() {
  POSTDISPLAY=''
  _faster_sg_str=''
  _faster_sg_last=''
  if [[ -n "$_faster_sg_region" ]]; then
    region_highlight=("${(@)region_highlight:#$_faster_sg_region}")
    _faster_sg_region=''
  fi
}

# --- wire up (idempotent: safe if sourced more than once) --------------
(( ${+_FASTER_SUGGEST_LOADED} )) && return
typeset -g _FASTER_SUGGEST_LOADED=1

autoload -Uz add-zle-hook-widget
zle -N _faster_sg_accept
zle -N _faster_sg_accept_word
add-zle-hook-widget line-pre-redraw _faster_sg_redraw
add-zle-hook-widget line-finish _faster_sg_finish

# Right-arrow fills the WHOLE suggestion. Bind both normal-mode (^[[C)
# and application-mode (^[OC) sequences so it works in any terminal.
for _faster_sg_k in '^[[C' '^[OC'; do
  bindkey "$_faster_sg_k" _faster_sg_accept
done
bindkey "$FASTER_SUGGEST_KEY" _faster_sg_accept

# Alt-Right accepts one WORD. Again both CSI and SS3 forms.
# ^[[1;3C = CSI with Alt modifier, ^[^[[C = ESC then normal Right,
# ^[f = classic readline Alt-f (forward-word with accept).
for _faster_sg_k in '^[[1;3C' '^[^[[C' '^[^[OC' '^[f'; do
  bindkey "$_faster_sg_k" _faster_sg_accept_word
done
unset _faster_sg_k
