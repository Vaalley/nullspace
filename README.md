# CHIP-8 Emulator (Odin)

A simple, readable CHIP-8 emulator written in [Odin](https://odin-lang.org/),
using [raylib](https://www.raylib.com/) for graphics.\
This project is designed for learning, clarity, and extensibility.

## Features

- Loads and runs CHIP-8 ROMs (default: `programs/ibm.c8`)
- Emulates display, memory, and basic instruction set
- Renders 64x32 monochrome graphics using raylib
- Easily extensible to support more CHIP-8 instructions

## Requirements

- [Odin compiler](https://odin-lang.org/download/)
- [raylib](https://github.com/raysan5/raylib) (Odin bindings are used, see
  vendor setup)
- A CHIP-8 ROM file (default: `programs/ibm.c8`)

## Getting Started

1. **Clone this repo and enter the directory:**
   ```sh
   git clone https://github.com/Vaalley/nullspace
   cd nullspace
   ```

2. **Place a CHIP-8 ROM in the `programs/` directory.**\
   By default, the emulator loads `programs/ibm.c8`.

3. **Build and run:**
   ```sh
   odin run .
   ```

4. **Controls:**\
   The emulator currently focuses on display and instruction execution.\
   (Input handling and sound are not yet implemented.)

## File Structure

- `main.odin` — Emulator entry point, CPU loop, instruction decoding
- `display.odin` — Display struct and graphics routines (draw, clear,
  drawSprite)
- `programs/` — Folder for CHIP-8 ROMs

## Extending

- To add more CHIP-8 instructions, edit the `instructions` array in `main.odin`.
- Display logic is encapsulated in `display.odin` for clarity and reusability.

## Troubleshooting

- If you see `Cycle limit reached. Possible infinite loop.`, the emulator hit a
  safety cap to prevent hanging. This usually means the loaded ROM requires more
  instructions to be implemented.
- Make sure your ROM path is correct and the file exists.

## Credits

- [Odin programming language](https://odin-lang.org/)
- [raylib](https://www.raylib.com/)
- CHIP-8 documentation:
  [Cowgod’s CHIP-8 Reference](http://devernay.free.fr/hacks/chip8/C8TECH10.HTM)
