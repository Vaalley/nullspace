package main

import "core:fmt"
import "core:mem"
import "core:os"
import "vendor:raylib"

kProgramStart :: 0x200 // 0x200 = 512
kProgramFilePath :: "programs/ibm.c8"

Instruction :: struct {
	mask:      u16,
	maskValue: u16,
	execute:   proc(opcode: u16, state: ^State),
}

// State holds the full emulation state, including registers, memory, and display
State :: struct {
	regProgramCounter: u16,
	regV:              [16]u8,
	regI:              u16,
	memory:            [4096]u8,
	display:           Display,
}

// main is the entry point for the CHIP-8 emulator
main :: proc() {
	state := State {
		regProgramCounter = kProgramStart,
	}

	init(&state.display)

	program_data, success := os.read_entire_file(kProgramFilePath)
	if !success {
		fmt.printfln("Error reading file: %s", kProgramFilePath)
		os.exit(1)
	}

	sprite_chars := [][5]u8 {
		{0xf0, 0x90, 0x90, 0x90, 0xf0}, // 0
		{0x20, 0x60, 0x20, 0x20, 0x70}, // 1
		{0xf0, 0x10, 0xf0, 0x80, 0xf0}, // 2
		{0xf0, 0x10, 0xf0, 0x10, 0xf0}, // 3
		{0x90, 0x90, 0xf0, 0x10, 0x10}, // 4
		{0xf0, 0x80, 0xf0, 0x10, 0xf0}, // 5
		{0xf0, 0x80, 0xf0, 0x90, 0xf0}, // 6
		{0xf0, 0x10, 0x20, 0x40, 0x40}, // 7
		{0xf0, 0x90, 0xf0, 0x90, 0xf0}, // 8
		{0xf0, 0x90, 0xf0, 0x10, 0xf0}, // 9
		{0xf0, 0x90, 0xf0, 0x90, 0x90}, // A
		{0xe0, 0x90, 0xe0, 0x90, 0xe0}, // B
		{0xf0, 0x80, 0x80, 0x80, 0xf0}, // C
		{0xe0, 0x90, 0x90, 0x90, 0xe0}, // D
		{0xf0, 0x80, 0xf0, 0x80, 0xf0}, // E
		{0xf0, 0x80, 0xf0, 0x80, 0x80}, // F
	}

	for sprite, i in sprite_chars {
		offset := i * 5
		for byte, j in sprite {
			state.memory[offset + j] = byte
		}
	}

	mem.copy(&state.memory[kProgramStart], &program_data[0], len(program_data))

	// Instruction set for CHIP-8
	instructions := []Instruction {
		Instruction {
			mask = 0xF000,
			maskValue = 0x6000,
			execute = proc(opcode: u16, state: ^State) {
				// Set Vx = kk.
				x := (opcode & 0x0F00) >> 8
				kk := u8(opcode & 0x00FF)
				state.regV[x] = kk
			},
		},
		Instruction {
			mask = 0xF0FF,
			maskValue = 0xF029,
			execute = proc(opcode: u16, state: ^State) {
				// Set I = location of sprite for digit Vx.
				x := (opcode & 0x0F00) >> 8
				state.regI = u16(state.regV[x]) * 5
			},
		},
		Instruction {
			mask = 0xFFFF,
			maskValue = 0x00E0,
			execute = proc(opcode: u16, state: ^State) {
				// Clear the display.
				clear(&state.display)
			},
		},
		Instruction {
			mask = 0xF000,
			maskValue = 0xD000,
			execute = proc(opcode: u16, state: ^State) {
				// Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
				x := (opcode & 0x0F00) >> 8
				y := (opcode & 0x00F0) >> 4
				n := opcode & 0x000F

				spriteData := state.memory[state.regI:state.regI + n]

				drawSprite(
					&state.display,
					state.regV[x],
					state.regV[y],
					spriteData,
					&state.regV[0xF],
				)
			},
		},
		Instruction {
			mask = 0xF000,
			maskValue = 0x1000,
			execute = proc(opcode: u16, state: ^State) {
				// Jump to location nnn.
				nnn := opcode & 0x0FFF
				state.regProgramCounter = nnn - 2
			},
		},
		Instruction {
			mask = 0xF000,
			maskValue = 0xA000,
			execute = proc(opcode: u16, state: ^State) {
				// Set I = nnn.
				nnn := opcode & 0x0FFF
				state.regI = nnn
			},
		},
		Instruction {
			mask = 0xF000,
			maskValue = 0x7000,
			execute = proc(opcode: u16, state: ^State) {
				// Set Vx = Vx + kk.
				x := (opcode & 0x0F00) >> 8
				kk := u8(opcode & 0x00FF)
				state.regV[x] += kk
			},
		},
	}

	// Main emulation loop with cycle limit to prevent infinite execution
	max_cycles := 1000000 // Set as needed for debugging
	cycles := 0
	for cycles < max_cycles {
		opcode :=
			(u16(state.memory[state.regProgramCounter]) << 8) |
			u16(state.memory[state.regProgramCounter + 1])
		hasMatch := false
		for instruction in instructions {
			isInstruction := opcode & instruction.mask == instruction.maskValue
			if isInstruction {
				hasMatch = true
				instruction.execute(opcode, &state)

				break
			}
		}

		if !hasMatch {
			fmt.printfln("Unknown instruction 0x%04X", opcode)
		}

		state.regProgramCounter += 2

		if state.regProgramCounter - kProgramStart >= u16(len(program_data)) {
			fmt.println("Program counter exceeded program length")
			break
		}
		cycles += 1
	}
	if cycles >= max_cycles {
		fmt.println("Cycle limit reached. Possible infinite loop.")
	}


	// Poll input until window closes
	for !raylib.WindowShouldClose() {
		raylib.PollInputEvents()
	}
}
