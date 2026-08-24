# faster-suggest

A lean, fast history autosuggest for **zsh** — a lighter replacement for
`zsh-users/zsh-autosuggestions`.

- No fpath pollution, no per-widget wrapping (uses native `line-pre-redraw`).
- Bounded recency scan (defaults to the last `5000` events — safe even if your
  `HISTSIZE` is huge).
- Ghost text via `POSTDISPLAY` + targeted `region_highlight` (single style).
- Right-arrow (`→`) accepts one char at a time; `Ctrl-E` accepts the whole
  suggestion.

## Install

```sh
git clone https://github.com/Hy4ri/faster-suggest ~/.zsh/plugins/faster-suggest
```

Source it from your `.zshrc` (no need to add anything to `$fpath`):

```sh
source ~/.zsh/plugins/faster-suggest/faster-suggest.zsh
```

## Config (set before sourcing)

| Variable                 | Default | Meaning                                  |
|--------------------------|---------|------------------------------------------|
| `FASTER_SUGGEST_HIGHLIGHT` | `fg=8` | Ghost-text color style                   |
| `FASTER_SUGGEST_SCAN`      | `5000`  | How many recent history events to scan   |
| `FASTER_SUGGEST_KEY`       | `^E`    | Accept-whole-suggestion key              |

## License

MIT © Hy4ri
