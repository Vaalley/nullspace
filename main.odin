package main

import "core:fmt"
import "core:math/rand"
import "core:mem"
import "core:os"
import "core:time"
import "vendor:raylib"

kProgramStart :: 0x200 // 0x200 = 512
kProgramFilePath :: "programs/octojam.c8"
kExecutionFrequency :: 520 // Hz
kTimerFrequency :: 60 // Hz - For regDT and regST

Instruction :: struct {
	mask:      u16,
	maskValue: u16,
	execute:   proc(opcode: u16, state: ^State),
}

// State holds the full emulation state, including registers, memory, and display
State :: struct {
	regProgramCounter:  u16,
	regV:               [16]u8,
	regI:               u16,
	regDT:              u8,
	regST:              u8,
	regStack:           [16]u16,
	regStackPointer:    u16,
	memory:             [4096]u8,
	display:            Display,
	waitingForKeypress: bool,
	keyRegister:        u8,
}

// sprite_chars is an array of 5-byte sprites for the digits 0-9 and A-F
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

// CHIP-8 key mapping to keyboard
// 1 2 3 C    →    1 2 3 4
// 4 5 6 D    →    Q W E R
// 7 8 9 E    →    A S D F
// A 0 B F    →    Z X C V
chip8_keys: [16]bool

// main is the entry point for the CHIP-8 emulator
main :: proc() {
	state := State {
		regProgramCounter  = kProgramStart,
		waitingForKeypress = false,
	}

	initializeDisplay(&state.display)

	program_data, success := os.read_entire_file(kProgramFilePath)
	if !success {
		fmt.printfln("Error reading file: %s", kProgramFilePath)
		os.exit(1)
	}

	for sprite, i in sprite_chars {
		offset := i * 5
		for byte, j in sprite {
			state.memory[offset + j] = byte
		}
	}

	mem.copy(&state.memory[kProgramStart], &program_data[0], len(program_data))

	// Main emulation loop
	frame_duration := time.Second / kExecutionFrequency
	timer_duration := time.Second / kTimerFrequency
	last_timer_update := time.now()
	for !raylib.WindowShouldClose() {
		raylib.PollInputEvents()
		frame_start := time.now()

		// Update key states every frame
		chip8_keys[0] = raylib.IsKeyDown(.X) // 0
		chip8_keys[1] = raylib.IsKeyDown(.ONE) // 1
		chip8_keys[2] = raylib.IsKeyDown(.TWO) // 2
		chip8_keys[3] = raylib.IsKeyDown(.THREE) // 3
		chip8_keys[4] = raylib.IsKeyDown(.Q) // 4
		chip8_keys[5] = raylib.IsKeyDown(.W) // 5
		chip8_keys[6] = raylib.IsKeyDown(.E) // 6
		chip8_keys[7] = raylib.IsKeyDown(.A) // 7
		chip8_keys[8] = raylib.IsKeyDown(.S) // 8
		chip8_keys[9] = raylib.IsKeyDown(.D) // 9
		chip8_keys[10] = raylib.IsKeyDown(.Z) // A
		chip8_keys[11] = raylib.IsKeyDown(.C) // B
		chip8_keys[12] = raylib.IsKeyDown(.FOUR) // C
		chip8_keys[13] = raylib.IsKeyDown(.R) // D
		chip8_keys[14] = raylib.IsKeyDown(.F) // E
		chip8_keys[15] = raylib.IsKeyDown(.V) // F

		// Check for key presses if we're waiting for one
		if state.waitingForKeypress {
			for i in 0 ..< 16 {
				if chip8_keys[i] {
					state.regV[state.keyRegister] = u8(i)
					state.waitingForKeypress = false
					break
				}
			}

			// Skip instruction execution if still waiting for keypress
			if state.waitingForKeypress {
				raylib.BeginDrawing()
				raylib.EndDrawing()
				continue
			}
		}

		opcode :=
			(u16(state.memory[state.regProgramCounter]) << 8) |
			u16(state.memory[state.regProgramCounter + 1])

		hasMatch := false
		for instruction in instructions {
			isInstruction := opcode & instruction.mask == instruction.maskValue
			if isInstruction {
				hasMatch = true
				// fmt.printfln("0x%04X", opcode)`
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

		timer_elapsed := time.since(last_timer_update)
		if timer_elapsed >= timer_duration {
			last_timer_update = time.now()
			if state.regDT > 0 {
				state.regDT -= 1
			}
		}

		execution_elapsed := time.since(frame_start)
		if execution_elapsed < frame_duration {
			time.sleep(frame_duration - execution_elapsed)
		}
	}
}

// Instruction set for CHIP-8
instructions := []Instruction {
	Instruction {
		mask = 0xFFFF,
		maskValue = 0x00E0,
		execute = proc(opcode: u16, state: ^State) {
			// Clear the display.

			clearDisplay(&state.display)
		},
	},
	Instruction {
		mask = 0xFFFF,
		maskValue = 0x00EE,
		execute = proc(opcode: u16, state: ^State) {
			// Return from a subroutine.

			if state.regStackPointer == 0 {
				fmt.println("Stack underflow")
				os.exit(1)
			}
			state.regStackPointer -= 1
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
		mask = 0xF00F,
		maskValue = 0x5000,
		execute = proc(opcode: u16, state: ^State) {
			// Skip next instruction if Vx = Vy.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			if state.regV[x] == state.regV[y] {
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
		mask = 0xF00F,
		maskValue = 0x8000,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = Vy.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			state.regV[x] = state.regV[y]
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x8001,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = Vx OR Vy.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			state.regV[x] = state.regV[x] | state.regV[y]
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x8002,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = Vx AND Vy.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			state.regV[x] = state.regV[x] & state.regV[y]
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x8003,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = Vx XOR Vy.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			state.regV[x] = state.regV[x] ~ state.regV[y]
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x8004,
		execute = proc(opcode: u16, state: ^State) {
			// 8xy4 - ADD Vx, Vy
			// The values of Vx and Vy are added together. If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, otherwise 0. Only the lowest 8 bits of the result are kept, and stored in Vx.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			state.regV[x] += state.regV[y]
			if state.regV[x] > 255 {
				state.regV[0xF] = 1
			} else {
				state.regV[0xF] = 0
			}
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x8005,
		execute = proc(opcode: u16, state: ^State) {
			// 8xy5 - SUB Vx, Vy
			// If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			if state.regV[x] > state.regV[y] {
				state.regV[0xF] = 1
			} else {
				state.regV[0xF] = 0
			}
			state.regV[x] -= state.regV[y]
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x8006,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = Vx SHR 1.
			// If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.

			x := (opcode & 0x0F00) >> 8
			state.regV[x] = state.regV[x] >> 1
			if state.regV[x] & 1 == 1 {
				state.regV[0xF] = 1
			} else {
				state.regV[0xF] = 0
			}
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x8007,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = Vy - Vx, set VF = NOT borrow.
			// If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy, and the results stored in Vx.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			if state.regV[y] > state.regV[x] {
				state.regV[0xF] = 1
			} else {
				state.regV[0xF] = 0
			}
			state.regV[x] = state.regV[y] - state.regV[x]
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x800E,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = Vx SHL 1.
			// If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.

			x := (opcode & 0x0F00) >> 8
			state.regV[x] = state.regV[x] << 1
			if state.regV[x] & 0x80 == 1 {
				state.regV[0xF] = 1
			} else {
				state.regV[0xF] = 0
			}
		},
	},
	Instruction {
		mask = 0xF00F,
		maskValue = 0x9000,
		execute = proc(opcode: u16, state: ^State) {
			// Skip next instruction if Vx != Vy.

			x := (opcode & 0x0F00) >> 8
			y := (opcode & 0x00F0) >> 4
			if state.regV[x] != state.regV[y] {
				state.regProgramCounter += 2
			}
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
		maskValue = 0xB000,
		execute = proc(opcode: u16, state: ^State) {
			// Jump to location nnn + V0.

			nnn := opcode & 0x0FFF
			state.regProgramCounter = nnn + u16(state.regV[(opcode & 0x0F00) >> 8]) - 2
		},
	},
	Instruction {
		mask = 0xF000,
		maskValue = 0xC000,
		execute = proc(opcode: u16, state: ^State) {
			// Set Vx = random byte AND kk.

			x := (opcode & 0x0F00) >> 8
			kk := u8(opcode & 0x00FF)

			random_byte := rand.uint32() & 0xFF
			state.regV[x] = u8(random_byte) & kk
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

			drawSprite(&state.display, state.regV[x], state.regV[y], spriteData, &state.regV[0xF])
		},
	},
	Instruction {
		mask = 0xF0FF,
		maskValue = 0xE09E,
		execute = proc(opcode: u16, state: ^State) {
			// Skip next instruction if key with the value of Vx is pressed.
			// Checks the keyboard, and if the key corresponding to the value of Vx is currently in the down position, PC is increased by 2.

			x := (opcode & 0x0F00) >> 8
			if chip8_keys[state.regV[x]] {
				state.regProgramCounter += 2
			}
		},
	},
	Instruction {
		mask = 0xF0FF,
		maskValue = 0xE0A1,
		execute = proc(opcode: u16, state: ^State) {
			// Skip next instruction if key with the value of Vx is not pressed.
			// Checks the keyboard, and if the key corresponding to the value of Vx is currently in the up position, PC is increased by 2.

			x := (opcode & 0x0F00) >> 8
			if !chip8_keys[state.regV[x]] {
				state.regProgramCounter += 2
			}
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
			// All execution stops until a key is pressed, then the value of that key is stored in Vx.

			x := (opcode & 0x0F00) >> 8
			state.waitingForKeypress = true
			state.keyRegister = u8(x)

			// The actual key detection is handled in the main loop
			// Execution will pause there until a key is pressed
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
		maskValue = 0xF018,
		execute = proc(opcode: u16, state: ^State) {
			// Set sound timer = Vx.

			x := (opcode & 0x0F00) >> 8
			state.regST = state.regV[x]
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
	Instruction {
		mask = 0xF0FF,
		maskValue = 0xF033,
		execute = proc(opcode: u16, state: ^State) {
			// Store BCD representation of Vx in memory locations I, I+1, and I+2.
			// The interpreter takes the decimal value of Vx, and places the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.

			x := (opcode & 0x0F00) >> 8
			state.memory[state.regI] = state.regV[x] / 100
			state.memory[state.regI + 1] = (state.regV[x] / 10) % 10
			state.memory[state.regI + 2] = state.regV[x] % 10
		},
	},
	Instruction {
		mask = 0xF0FF,
		maskValue = 0xF055,
		execute = proc(opcode: u16, state: ^State) {
			// Store registers V0 through Vx in memory starting at location I.

			x := (opcode & 0x0F00) >> 8
			for i in 0 ..= x {
				state.memory[state.regI + u16(i)] = state.regV[i]
			}
		},
	},
	Instruction {
		mask = 0xF0FF,
		maskValue = 0xF065,
		execute = proc(opcode: u16, state: ^State) {
			// Read registers V0 through Vx from memory starting at location I.

			x := (opcode & 0x0F00) >> 8
			for i in 0 ..= x {
				state.regV[i] = state.memory[state.regI + u16(i)]
			}
		},
	},
}
