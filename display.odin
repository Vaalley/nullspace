package main

import "vendor:raylib"

WIDTH :: i32(64)
HEIGHT :: i32(32)
PIXEL_SIZE :: i32(10)

// Display represents a 64x32 monochrome pixel buffer
Display :: struct {
	pixels: [WIDTH][HEIGHT]bool,
}

// draw renders the display buffer to the window
draw := proc(display: ^Display) {
	raylib.BeginDrawing()
	for y in 0 ..< HEIGHT {
		for x in 0 ..< WIDTH {
			raylib.DrawRectangle(
				x * PIXEL_SIZE,
				y * PIXEL_SIZE,
				PIXEL_SIZE,
				PIXEL_SIZE,
				display.pixels[x][y] ? raylib.WHITE : raylib.BLACK,
			)
		}
	}

	raylib.EndDrawing()
}

// drawSprite draws an n-byte sprite at (offsetX, offsetY) and sets collisionRef to 1 if any pixels are unset
drawSprite := proc(
	display: ^Display,
	offsetX: u8,
	offsetY: u8,
	charData: []u8,
	collisionRef: ^u8,
) {
	collisionRef^ = 0 // Reset collision at the start
	for y in 0 ..< len(charData) {
		if u8(y) + offsetY >= u8(HEIGHT) {
			continue
		}
		for x in 0 ..< 8 {
			if u8(x) + offsetX >= u8(WIDTH) {
				continue
			}
			bit := (charData[y] >> u16(7 - x)) & 1
			old_pixel := display.pixels[u8(x) + offsetX][u8(y) + offsetY]
			new_pixel := old_pixel ~ (bit == 1)
			if old_pixel && (bit == 1) {
				collisionRef^ = 1
			}
			setPixelAt(display, u8(x) + offsetX, u8(y) + offsetY, new_pixel)
		}
	}
	draw(display)
}

// setPixelAt sets a pixel if within bounds
setPixelAt := proc(display: ^Display, x: u8, y: u8, is_white: bool) {
	if u8(x) < u8(WIDTH) && u8(y) < u8(HEIGHT) {
		display.pixels[x][y] = is_white
	}
}

// clear sets all pixels to black and redraws
clearDisplay := proc(display: ^Display) {
	for y in 0 ..< HEIGHT {
		for x in 0 ..< WIDTH {
			display.pixels[x][y] = false
		}
	}
	draw(display)
}

// init initializes the display window
initializeDisplay := proc(display: ^Display) {
	raylib.InitWindow(WIDTH * PIXEL_SIZE, HEIGHT * PIXEL_SIZE, "64x32 Display")
}
