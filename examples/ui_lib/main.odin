package ui_lib

import k2 "../.."
import ui "ui"

SCREEN_WIDTH :: 1000
SCREEN_HEIGHT :: 750

ui_context: ^ui.UI_Context
slider_value: f32 = 50
toggle_value: bool
segment_selected: u32
segment_entries := [?]string{"Low", "Mid", "High"}
image_texture: k2.Texture

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	k2.init(SCREEN_WIDTH, SCREEN_HEIGHT, "UI LIB", options = {window_mode = .Windowed})
	ui_context = ui.init(padding = 4, corner = 0.2)
	image_texture = k2.load_texture_from_bytes(#load("../raylib_ports/shaders_texture_waves/space.png"))
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	dt := k2.get_frame_time()
	mouse_pos := k2.get_mouse_position()

	ui.update_mouse_pos(ui_context, mouse_pos)
	if k2.mouse_button_went_down(.Left) do ui.update_mouse_button(ui_context, .Pressed)
	else if k2.mouse_button_went_up(.Left) do ui.update_mouse_button(ui_context, .Released)

	k2.clear(k2.BLACK)

	ui.begin_frame(ui_context, dt)
	draw_ui()
	ui.end_frame(ui_context)

	k2.draw_rect_rounded({400, 400, 300, 300}, 0.2, k2.WHITE)

	k2.present()

	free_all(context.temp_allocator)
	return true
}

draw_ui :: proc() {
	fullscreen_rect := k2.Rect{0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}
	left_panel_rect := ui.cut_left(&fullscreen_rect, 200)

	k2.draw_rect(left_panel_rect, k2.ORANGE)
	k2.draw_rect(fullscreen_rect, k2.GREEN)

	row := ui.cut_standard_row(ui_context, &left_panel_rect)
	k2.draw_rect(row, k2.RED)
	ui.label(ui_context, row, "Hello, world")

	row = ui.cut_standard_row(ui_context, &left_panel_rect)
	k2.draw_rect(row, k2.WHITE)
	ui.separator(ui_context, row)

	row = ui.cut_standard_row(ui_context, &left_panel_rect)
	ui.cut_inset(&row, ui_context.padding, 1)
	ui.button_label(ui_context, row, "Press me UWU")

	slider_rect := ui.cut_row(
		&left_panel_rect,
		ui_context.row_height * 2 + ui_context.padding,
		ui_context.padding,
	)
	ui.cut_inset(&slider_rect, ui_context.padding, 1)
	ui.slider(ui_context, slider_rect, "Speed", 0, 100, 0.25, &slider_value)

	progress_rect := ui.cut_standard_row(ui_context, &left_panel_rect)
	ui.cut_inset(&progress_rect, ui_context.padding, 1)
	ui.progress_bar(ui_context, progress_rect, "Speed", 0, 100, slider_value)

	row = ui.cut_standard_row(ui_context, &left_panel_rect)
	ui.cut_inset(&row, ui_context.padding, 1)
	ui.toggle(ui_context, row, "Enabled", &toggle_value)

	row = ui.cut_standard_row(ui_context, &left_panel_rect)
	ui.cut_inset(&row, ui_context.padding, 1)
	ui.segmented(ui_context, row, segment_entries[:], &segment_selected)

	image_rect := ui.cut_row(&left_panel_rect, 140, ui_context.padding)
	ui.cut_inset(&image_rect, ui_context.padding, 1)
	ui.image(ui_context, image_rect, image_texture)
}

shutdown :: proc() {
	k2.destroy_texture(image_texture)
	k2.shutdown()
}
