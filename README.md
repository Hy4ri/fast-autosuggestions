# fast-autosuggestions

A blazing fast, zero-overhead history autosuggest for **zsh** — a modern, lighter replacement for `zsh-users/zsh-autosuggestions`.

- **Pure C-Level Pattern Matching:** Uses native Zsh `${history[(r)${pat}]}` pattern indexing directly in C memory — no subshells, no fork/exec (`awk`/`fc`), and no interpreted history loops.
- **Forward-Typing Memoization:** Forward keystrokes that match the current suggestion skip history lookups entirely (0ms overhead per key).
- **Safe Syntax Highlighting Integration:** Cooperates with `fast-syntax-highlighting` and `zsh-syntax-highlighting` via targeted in-place `region_highlight` updates — never clobbers syntax colors.
- **Smart Navigation:** Right-arrow (`→`) accepts full suggestions when at end-of-line, while preserving normal cursor movement when editing within the buffer.
- **Word-by-Word Acceptance:** Step through suggestions incrementally with `Alt+→` or `Alt-f`.

## Keybindings

| Key | Action |
| --- | --- |
| `→` (Right Arrow) | **Smart Accept:** Accepts full suggestion at EOL; moves cursor normally inside text |
| `Ctrl-E` (or `$FAST_AUTOSUGGEST_KEY`) | Accepts the **whole** suggestion anywhere |
| `Alt+→` / `Alt-f` | Accepts **one word** at a time |

*(Works out of the box with both standard CSI and application-mode keypad sequences).*

## Install

Clone into your Zsh plugins directory:

```sh
git clone https://github.com/Hy4ri/fast-autosuggestions ~/.zsh/plugins/fast-autosuggestions
```

Source it from your `.zshrc` (load it *after* syntax highlighting):

```sh
source ~/.zsh/plugins/fast-autosuggestions/fast-autosuggestions.zsh
```

## Configuration

Set any of these variables before sourcing the script:

| Variable | Default | Description |
| --- | --- | --- |
| `FAST_AUTOSUGGEST_HIGHLIGHT` | `fg=8` | Ghost text highlight style (e.g. `fg=8`, `fg=244`, `bold`) |
| `FAST_AUTOSUGGEST_KEY` | `^E` | Keybinding to accept the whole suggestion |

## License

MIT © Hy4ri
