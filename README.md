# 🧬 _(Yet Another)_ Conway’s Game of Life

A lightweight [TUI](https://en.wikipedia.org/wiki/Text-based_user_interface)
version of
[Conway's Game of Life](https://en.wikipedia.org/wiki/Conway%27s_Game_of_Life),
written to learn [Zig](https://ziglang.org/).

<p align="center">
  <img src="./docs/assets/example.gif" />
</p>

## What is Conway’s Game of Life?

Conway’s Game of Life is a cellular automaton devised by mathematician John
Conway in 1970. It’s not a traditional game, there are no players, but a
simulation that evolves over time based on simple rules.

Each cell on the grid is either alive or dead. At every tick _(generation)_, all
cells update simultaneously based on their neighbors:

- A dead cell with exactly 3 neighbors becomes alive (birth).
- A live cell with 2 or 3 neighbors survives.
- All other live cells die _(loneliness or overcrowding)_.

Despite its simplicity, the system exhibits complex, emergent behavior, patterns
that move, replicate, and even compute.

## Requirements

- [mise](https://mise.jdx.dev/)
- [Zig](https://ziglang.org/) 0.17.0 (pinned in `mise.toml`)

## Run / Test / Format

```bash
# build and run
mise run run
# test
mise run test
# check format
mise run fmt
# auto format
mise run fix
# run everything CI runs
mise run check
# record a new docs/assets/example.gif
mise run gif
```

## Options

| Flag             | Description                                                                 |
| ---------------- | --------------------------------------------------------------------------- |
| `--seed <n>`     | seed the world generator for a reproducible run                             |
| `--headless`     | skip the terminal capability query and mouse setup (for headless recording) |
| `--duration <s>` | exit on its own after `s` seconds                                           |
| `-h`, `--help`   | print usage and exit                                                        |

```bash
mise run run -- --seed 42
```

## Interactive Commands

| Key     |               Action |
| :------ | -------------------: |
| `g`     |  spawn random glider |
| `c`     |      clear the board |
| `r`     | reset to random seed |
| `space` |       pause / resume |
| `→`     |             speed up |
| `←`     |            slow down |
| `click` |    draw cells (drag) |
| `q`     |                 quit |
