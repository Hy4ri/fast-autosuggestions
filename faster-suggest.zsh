# faster-suggest.zsh
# Lean history autosuggest for zsh — a lighter, faster replacement for
# zsh-users/zsh-autosuggestions. No fpath pollution, no widget wrapping,
# C-level pattern scanning. Source it from your .zshrc.
#
# Config (override before sourcing):
#   FASTER_SUGGEST_HIGHLIGHT  ghost-text color style   (default: fg=8)
#   FASTER_SUGGEST_KEY        whole-suggestion accept key (default: ^E)
#
# Right-arrow (or $FASTER_SUGGEST_KEY / Ctrl-E) accepts the WHOLE suggestion.
# Alt-right accepts one WORD at a time.

# --- config -------------------------------------------------------------
typeset -g FASTER_SUGGEST_HIGHLIGHT="${FASTER_SUGGEST_HIGHLIGHT:-fg=8}"
typeset -g FASTER_SUGGEST_KEY="${FASTER_SUGGEST_KEY:-^E}"

# --- internal state -----------------------------------------------------
typeset -g _faster_sg_str=''
typeset -g _faster_sg_last=''
typeset -g _faster_sg_region=''   # exact region_highlight entry we own

# Fetch the best (newest) history line that STARTS with $1.
# PURE ZSH C-LEVEL PATTERN MATCH: No shell loop, no subshell.
# Uses ${history[(R)pat]} which executes in native C.
_faster_sg_fetch() {
  local buf="$1" pat
  _faster_sg_str=''
  [[ -z "$buf" ]] && return

  pat="${(b)buf}*"              # (b) escapes glob metachars — literal prefix match
  _faster_sg_str="${history[(r)${pat}]}"  # (r) returns the single newest matching line directly
  [[ -z "$_faster_sg_str" ]] && _faster_sg_str="${history[(R)${pat}]}"
}

# Repaint ghost text after redraw.
_faster_sg_redraw() {
  local buf="$BUFFER"

  # 1. Pure cursor move / unrelated redraw — buffer text unchanged, nothing to do
  if [[ "$buf" == "$_faster_sg_last" ]]; then
    return
  fi

  # 2. Forward-typing memoization: if new text simply extends previous buffer
  # and the existing suggestion already matches, keep it without rescanning!
  if [[ "$buf" == "${_faster_sg_last}"* && -n "$_faster_sg_str" && "$_faster_sg_str" == "$buf"* ]]; then
    :
  else
    _faster_sg_fetch "$buf"
  fi
  _faster_sg_last="$buf"

  # 3. Drop previous highlight entry via exact match lookup (ie)
  if [[ -n "$_faster_sg_region" ]]; then
    local idx="${region_highlight[(ie)$_faster_sg_region]}"
    (( idx <= ${#region_highlight} )) && region_highlight[idx]=()
    _faster_sg_region=''
  fi

  # 4. Apply new suggestion highlight if available
  if [[ -n "$_faster_sg_str" && "$_faster_sg_str" != "$buf" ]]; then
    local rest="${_faster_sg_str#"$buf"}"
    POSTDISPLAY="$rest"
    local len="${#buf}"
    local entry="$len $((len + ${#rest})) $FASTER_SUGGEST_HIGHLIGHT"
    region_highlight+=("$entry")
    _faster_sg_region="$entry"
  else
    POSTDISPLAY=''
  fi
}

# Trigger syntax highlighting update if present.
_faster_sg_rehighlight() {
  (( $+functions[_zsh_highlight] )) && _zsh_highlight
}

# Accept the WHOLE suggestion at once.
_faster_sg_accept() {
  if [[ -n "$POSTDISPLAY" ]]; then
    BUFFER="$_faster_sg_str"
    CURSOR="${#BUFFER}"
    POSTDISPLAY=''
    # NOTE: _faster_sg_last is intentionally NOT set here so that
    # _faster_sg_redraw catches the buffer change and cleans up region_highlight.
    _faster_sg_rehighlight
  else
    zle .forward-char
  fi
}

# Accept one WORD of the suggestion (Alt-Right behavior).
_faster_sg_accept_word() {
  if [[ -z "$POSTDISPLAY" ]]; then
    zle .forward-word
    return
  fi

  local rest="$POSTDISPLAY" grab=""

  # 1. Grab leading whitespace
  local ws="${rest%%[![:space:]]*}"
  grab+="$ws"
  rest="${rest#$ws}"

  # 2. Grab the word itself
  local w="${rest%%[[:space:]]*}"
  grab+="$w"
  rest="${rest#$w}"

  # 3. Grab trailing whitespace so cursor lands cleanly at next word start
  local tws="${rest%%[![:space:]]*}"
  grab+="$tws"

  if [[ -n "$grab" ]]; then
    BUFFER+="$grab"
    CURSOR="${#BUFFER}"
    POSTDISPLAY="${_faster_sg_str#"$BUFFER"}"
    # NOTE: _faster_sg_last is intentionally NOT set here so that
    # _faster_sg_redraw catches the buffer change and updates region_highlight.
    _faster_sg_rehighlight
  fi
}

# Clear ghost text on Enter.
_faster_sg_finish() {
  POSTDISPLAY=''
  _faster_sg_str=''
  _faster_sg_last=''
  if [[ -n "$_faster_sg_region" ]]; then
    local idx="${region_highlight[(ie)$_faster_sg_region]}"
    (( idx <= ${#region_highlight} )) && region_highlight[idx]=()
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

# Right-arrow fills the WHOLE suggestion (both CSI and SS3 / app-mode keypad)
for _faster_sg_k in '^[[C' '^[OC'; do
  bindkey "$_faster_sg_k" _faster_sg_accept
done
bindkey "$FASTER_SUGGEST_KEY" _faster_sg_accept

# Alt-Right accepts one WORD
for _faster_sg_k in '^[[1;3C' '^[^[[C' '^[^[OC' '^[f'; do
  bindkey "$_faster_sg_k" _faster_sg_accept_word
done
unset _faster_sg_k
