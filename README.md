# CHIP-8 Emulator (Odin)

A simple, readable CHIP-8 emulator written in [Odin](https://odin-lang.org/),
using [raylib](https://www.raylib.com/) for graphics, input, and audio.\
This project is designed for learning, clarity, and extensibility.

## Features

- Loads and runs CHIP-8 ROMs (roms in `programs/`)
- Emulates display, memory, and basic instruction set
- Renders 64x32 monochrome graphics using raylib
- Easily extensible to support more CHIP-8 instructions

## Requirements

- [Odin](https://odin-lang.org/download/)

## Getting Started

1. **Clone this repo and enter the directory:**
   ```sh
   git clone https://github.com/Vaalley/nullspace
   cd nullspace
   ```

2. **Build and run:**
   ```sh
   odin run .
   ```

## File Structure

- `main.odin` — Emulator entry point, CPU loop, instruction decoding
- `programs/` — Folder for CHIP-8 ROMs

## Extending

- To add more CHIP-8 instructions, edit the `instructions` array in `main.odin`.

## Credits

- [Odin programming language](https://odin-lang.org/)
- [raylib](https://www.raylib.com/)
- CHIP-8 documentation:
  [Cowgod’s CHIP-8 Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
