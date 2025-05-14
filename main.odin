package main

import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"
import "vendor:raylib"

kProgramStart :: 0x200 // 0x200 = 512
kProgramFilePath :: "programs/pong.c8"
kExecutionFrequency :: 520 // Hz
kTimerFrequency :: 60 // Hz - For regDT and regST

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
	regDT:             u8,
	regST:             u8,
	regStack:          [16]u16,
	regStackPointer:   u16,
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
			mask = 0xFFFF,
			maskValue = 0x00E0,
			execute = proc(opcode: u16, state: ^State) {
				// Clear the display.

				clear(&state.display)
			},
		},
		Instruction {
			mask = 0xFFFF,
			maskValue = 0x00EE,
			execute = proc(opcode: u16, state: ^State) {
				// Return from a subroutine.

				state.regStackPointer -= 1
				if state.regStackPointer < 0 {
					fmt.println("Stack underflow")
					os.exit(1)
				}
				state.regProgramCounter = state.regStack[state.regStackPointer]
			},
		},
		Instruction {
			mask = 0xF000,
			maskValue = 0x0000,
			execute = proc(opcode: u16, state: ^State) {
				// Jump to a machine code routine at nnn.

				// This instruction is only used on the old computers on which Chip-8 was originally implemented. It is ignored by modern interpreters.
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
			maskValue = 0x2000,
			execute = proc(opcode: u16, state: ^State) {
				// Call subroutine at nnn.

				nnn := opcode & 0x0FFF
				state.regStack[state.regStackPointer] = state.regProgramCounter
				state.regStackPointer += 1
				if state.regStackPointer >= 16 {
					fmt.println("Stack overflow")
					os.exit(1)
				}
				state.regProgramCounter = nnn - 2
			},
		},
		Instruction {
			mask = 0xF000,
			maskValue = 0x3000,
			execute = proc(opcode: u16, state: ^State) {
				// Skip next instruction if Vx = kk.

				x := (opcode & 0x0F00) >> 8
				kk := u8(opcode & 0x00FF)
				if state.regV[x] == kk {
					state.regProgramCounter += 2
				}
			},
		},
		Instruction {
			mask = 0xF000,
			maskValue = 0x4000,
			execute = proc(opcode: u16, state: ^State) {
				// Skip next instruction if Vx != kk.

				x := (opcode & 0x0F00) >> 8
				kk := u8(opcode & 0x00FF)
				if state.regV[x] != kk {
					state.regProgramCounter += 2
				}
			},
		},
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
			mask = 0xF000,
			maskValue = 0x7000,
			execute = proc(opcode: u16, state: ^State) {
				// Set Vx = Vx + kk.

				x := (opcode & 0x0F00) >> 8
				kk := u8(opcode & 0x00FF)
				state.regV[x] += kk
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
			mask = 0xF0FF,
			maskValue = 0xF007,
			execute = proc(opcode: u16, state: ^State) {
				// Set Vx = delay timer value.

				x := (opcode & 0x0F00) >> 8
				state.regV[x] = state.regDT
			},
		},
		Instruction {
			mask = 0xF0FF,
			maskValue = 0xF00A,
			execute = proc(opcode: u16, state: ^State) {
				// Wait for a key press, store the value of the key in Vx.

				// TODO
			},
		},
		Instruction {
			mask = 0xF0FF,
			maskValue = 0xF015,
			execute = proc(opcode: u16, state: ^State) {
				// Set delay timer = Vx.

				x := (opcode & 0x0F00) >> 8
				state.regDT = state.regV[x]
			},
		},
		Instruction {
			mask = 0xF0FF,
			maskValue = 0xF01E,
			execute = proc(opcode: u16, state: ^State) {
				// Set I = I + Vx.

				x := (opcode & 0x0F00) >> 8
				state.regI += u16(state.regV[x])
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
	}

	// Main emulation loop
	frame_duration := time.Second / kExecutionFrequency
	timer_duration := time.Second / kTimerFrequency
	last_timer_update := time.now()
	for {
		frame_start := time.now()

		opcode :=
			(u16(state.memory[state.regProgramCounter]) << 8) |
			u16(state.memory[state.regProgramCounter + 1])
		hasMatch := false
		for instruction in instructions {
			isInstruction := opcode & instruction.mask == instruction.maskValue
			if isInstruction {
				hasMatch = true
				// fmt.printfln("0x%04X", opcode)
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

		// Update timers at 60Hz
		timer_elapsed := time.since(last_timer_update)
		if timer_elapsed >= timer_duration {
			last_timer_update = time.now()
			if state.regDT > 0 {
				state.regDT -= 1
			}
			// Also handle sound timer here if needed
			if state.regST > 0 {
				state.regST -= 1
			}
		}

		elapsed := time.since(frame_start)
		if elapsed < frame_duration {
			time.sleep(frame_duration - elapsed)
		}
	}


	// Poll input until window closes
	for !raylib.WindowShouldClose() {
		raylib.PollInputEvents()
	}
}
