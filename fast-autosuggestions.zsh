# fast-autosuggestions.zsh
# Lean history autosuggest for zsh — a lighter, faster replacement for
# zsh-users/zsh-autosuggestions. No fpath pollution, no widget wrapping,
# C-level pattern scanning. Source it from your .zshrc.
#
# Config (override before sourcing):
#   FAST_AUTOSUGGEST_HIGHLIGHT  ghost-text color style   (default: fg=8)
#   FAST_AUTOSUGGEST_KEY        whole-suggestion accept key (default: ^E)
#
# Right-arrow (or $FAST_AUTOSUGGEST_KEY / Ctrl-E) accepts the WHOLE suggestion.
# Alt-right accepts one WORD at a time.

# --- config -------------------------------------------------------------
typeset -g FAST_AUTOSUGGEST_HIGHLIGHT="${FAST_AUTOSUGGEST_HIGHLIGHT:-fg=8}"
typeset -g FAST_AUTOSUGGEST_KEY="${FAST_AUTOSUGGEST_KEY:-^E}"

# --- internal state -----------------------------------------------------
typeset -g _fast_as_str=''
typeset -g _fast_as_last=''
typeset -g _fast_as_region=''   # exact region_highlight entry we own

# Fetch the best (newest) history line that STARTS with $1.
# PURE ZSH C-LEVEL PATTERN MATCH: No shell loop, no subshell.
# Uses ${history[(r)pat]} which executes in native C and returns the single
# newest matching line without word-splitting or multi-match space concatenation.
_fast_as_fetch() {
  local buf="$1" pat
  _fast_as_str=''
  [[ -z "$buf" ]] && return

  pat="${(b)buf}*"              # (b) escapes glob metachars — literal prefix match
  _fast_as_str="${history[(r)${pat}]}"
}

# Repaint ghost text after redraw.
_fast_as_redraw() {
  local buf="$BUFFER"

  # 1. Pure cursor move / unrelated redraw — buffer text unchanged, nothing to do
  # ...unless something (fzf-tab, syntax highlighters) rebuilt region_highlight
  # and dropped our ghost-text entry: then just restore it.
  if [[ "$buf" == "$_fast_as_last" ]]; then
    if [[ -n "$_fast_as_region" && -n "$POSTDISPLAY" ]] \
       && (( ${region_highlight[(ie)$_fast_as_region]} > ${#region_highlight} )); then
      region_highlight+=("$_fast_as_region")
    fi
    return
  fi

  # 2. Forward-typing memoization: if new text simply extends previous buffer
  # and the existing suggestion already matches, keep it without rescanning!
  if [[ "$buf" == "${_fast_as_last}"* && -n "$_fast_as_str" && "$_fast_as_str" == "$buf"* ]]; then
    :
  else
    _fast_as_fetch "$buf"
  fi
  _fast_as_last="$buf"

  # 3. Drop previous highlight entry via exact match lookup (ie)
  if [[ -n "$_fast_as_region" ]]; then
    local idx="${region_highlight[(ie)$_fast_as_region]}"
    (( idx <= ${#region_highlight} )) && region_highlight[idx]=()
    _fast_as_region=''
  fi

  # 4. Apply new suggestion highlight if available
  if [[ -n "$_fast_as_str" && "$_fast_as_str" != "$buf" ]]; then
    local rest="${_fast_as_str#"$buf"}"
    POSTDISPLAY="$rest"
    local len="${#buf}"
    local entry="$len $((len + ${#rest})) $FAST_AUTOSUGGEST_HIGHLIGHT"
    region_highlight+=("$entry")
    _fast_as_region="$entry"
  else
    POSTDISPLAY=''
  fi
}

# Trigger syntax highlighting update if present.
_fast_as_rehighlight() {
  (( $+functions[_zsh_highlight] )) && _zsh_highlight
}

# Accept the WHOLE suggestion at once.
_fast_as_accept() {
  if [[ -n "$POSTDISPLAY" ]]; then
    BUFFER="$_fast_as_str"
    CURSOR="${#BUFFER}"
    POSTDISPLAY=''
    # NOTE: _fast_as_last is intentionally NOT set here so that
    # _fast_as_redraw catches the buffer change and cleans up region_highlight.
    _fast_as_rehighlight
  else
    zle .forward-char
  fi
}

# Accept one WORD of the suggestion (Alt-Right behavior).
_fast_as_accept_word() {
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
    POSTDISPLAY="${_fast_as_str#"$BUFFER"}"
    # NOTE: _fast_as_last is intentionally NOT set here so that
    # _fast_as_redraw catches the buffer change and updates region_highlight.
    _fast_as_rehighlight
  fi
}

# Clear ghost text on Enter.
_fast_as_finish() {
  POSTDISPLAY=''
  _fast_as_str=''
  _fast_as_last=''
  if [[ -n "$_fast_as_region" ]]; then
    local idx="${region_highlight[(ie)$_fast_as_region]}"
    (( idx <= ${#region_highlight} )) && region_highlight[idx]=()
    _fast_as_region=''
  fi
}

# --- wire up (idempotent: safe if sourced more than once) --------------
(( ${+_FAST_AUTOSUGGEST_LOADED} )) && return
typeset -g _FAST_AUTOSUGGEST_LOADED=1

autoload -Uz add-zle-hook-widget
zle -N _fast_as_accept
zle -N _fast_as_accept_word
add-zle-hook-widget line-pre-redraw _fast_as_redraw
add-zle-hook-widget line-finish _fast_as_finish

# Right-arrow: Smart Accept (only accept suggestion if cursor is at EOL,
# otherwise move cursor forward normally).
_fast_as_smart_right() {
  if [[ -n "$POSTDISPLAY" && $CURSOR -eq ${#BUFFER} ]]; then
    _fast_as_accept
  else
    zle .forward-char
  fi
}
zle -N _fast_as_smart_right

# Bind Right-arrow to smart-right
for _fast_as_k in '^[[C' '^[OC'; do
  bindkey "$_fast_as_k" _fast_as_smart_right
done
bindkey "$FAST_AUTOSUGGEST_KEY" _fast_as_accept

# Alt-Right accepts one WORD
for _fast_as_k in '^[[1;3C' '^[^[[C' '^[^[OC' '^[f'; do
  bindkey "$_fast_as_k" _fast_as_accept_word
done
unset _fast_as_k
