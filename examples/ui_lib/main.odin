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
page_scroll: ui.Scroll_State
page_volume: f32 = 65
page_notifications := true
page_quality: u32 = 1

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	k2.init(SCREEN_WIDTH, SCREEN_HEIGHT, "UI LIB", options = {window_mode = .Windowed})
	ui_context = ui.init(padding = 4, corner = 6)
	image_texture = k2.load_texture_from_bytes(#load("../raylib_ports/shaders_texture_waves/space.png"))
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	dt := k2.get_frame_time()
	mouse_pos := k2.get_mouse_position()

	ui.update_mouse_pos(ui_context, mouse_pos)
	ui.update_scroll_delta(ui_context, k2.get_mouse_wheel_delta())
	if k2.mouse_button_went_down(.Left) do ui.update_mouse_button(ui_context, .Pressed)
	else if k2.mouse_button_went_up(.Left) do ui.update_mouse_button(ui_context, .Released)

	k2.clear({0xE3, 0xEB, 0xF3, 0xFF})

	ui.begin_frame(ui_context, dt)
	draw_ui()
	ui.end_frame(ui_context)

	k2.present()

	free_all(context.temp_allocator)
	return true
}

draw_ui :: proc() {
	fullscreen_rect := k2.Rect{0, 0, SCREEN_WIDTH, SCREEN_HEIGHT}
	left_panel_rect := ui.cut_left(&fullscreen_rect, 260)

	draw_page(fullscreen_rect)
	ui.cut_inset(&left_panel_rect, 20, 20)
	left_panel_rect = ui.panel(ui_context, left_panel_rect, 16)
	defer ui.panel_end(ui_context)

	row := ui.cut_row(&left_panel_rect, 42, 4)
	ui.label(ui_context, row, "Quick controls", font_size = 24, hor_align = .Left)

	row = ui.cut_row(&left_panel_rect, 1, 16)
	ui.separator(ui_context, row)

	row = ui.cut_row(&left_panel_rect, 40, 16)
	ui.cut_inset(&row, ui_context.padding, 1)
	ui.button_label(ui_context, row, "Launch")

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

draw_page :: proc(rect: k2.Rect) {
	rect := rect
	ui.cut_inset(&rect, 20, 20)
	page := ui.panel(ui_context, rect, 20)
	defer ui.panel_end(ui_context)

	ui.label(ui_context, ui.cut_row(&page, 42, 4), "Mission control", font_size = 30, hor_align = .Left)
	ui.label(ui_context, ui.cut_row(&page, 28, 12), "Your workspace, tuned for the next adventure.", hor_align = .Left)
	ui.separator(ui_context, ui.cut_row(&page, 1, 16))

	viewport := page
	page_scroll.content_height = 1150
	content := ui.begin_scroll(ui_context, viewport, &page_scroll)
	ui.cut_inset(&content, 0, 4)
	content.w -= 12

	ui.image(ui_context, ui.cut_row(&content, 220, 16), image_texture)
	ui.label(ui_context, ui.cut_row(&content, 36, 4), "Ready for launch", font_size = 26, hor_align = .Left)
	ui.label(ui_context, ui.cut_row(&content, 28, 20), "Explore the controls below to make this space your own.", hor_align = .Left)

	settings := ui.panel(ui_context, ui.cut_row(&content, 240, 20), 16)
	ui.label(ui_context, ui.cut_row(&settings, 32, 12), "Preferences", font_size = 24, hor_align = .Left)
	ui.toggle(ui_context, ui.cut_standard_row(ui_context, &settings), "Notifications", &page_notifications)
	ui.label(ui_context, ui.cut_standard_row(ui_context, &settings), "Visual quality", hor_align = .Left)
	ui.segmented(ui_context, ui.cut_standard_row(ui_context, &settings), segment_entries[:], &page_quality)
	ui.slider(ui_context, settings, "Audio level", 0, 100, 1, &page_volume, "%.0f%%")
	ui.panel_end(ui_context)

	status := ui.panel(ui_context, ui.cut_row(&content, 160, 20), 16)
	ui.label(ui_context, ui.cut_row(&status, 32, 12), "Launch checklist", font_size = 24, hor_align = .Left)
	ui.progress_bar(ui_context, ui.cut_standard_row(ui_context, &status), "Assets", 0, 100, 100, "%.0f%%")
	ui.progress_bar(ui_context, ui.cut_standard_row(ui_context, &status), "Systems", 0, 100, 75, "%.0f%%")
	ui.progress_bar(ui_context, ui.cut_standard_row(ui_context, &status), "Fuel", 0, 100, slider_value, "%.0f%%")
	ui.panel_end(ui_context)

	notes := ui.panel(ui_context, ui.cut_row(&content, 210, 20), 16)
	ui.label(ui_context, ui.cut_row(&notes, 32, 12), "Before you go", font_size = 24, hor_align = .Left)
	note_lines := [?]string {
		"Use the wheel to explore this page.",
		"Drag the scrollbar thumb for a quick jump.",
		"Click the track to move to another section.",
		"Your preferences stay with you as you scroll.",
	}
	for text in note_lines {
		ui.label(ui_context, ui.cut_standard_row(ui_context, &notes), text, hor_align = .Left)
	}
	ui.panel_end(ui_context)

	if ui.button_label(ui_context, ui.cut_row(&content, 40, 12), "Reset preferences") {
		page_notifications = true
		page_quality = 1
		page_volume = 65
	}
	ui.label(ui_context, ui.cut_standard_row(ui_context, &content), "All set. Enjoy the journey.")
	ui.end_scroll(ui_context, viewport, &page_scroll)
}

shutdown :: proc() {
	k2.destroy_texture(image_texture)
	k2.shutdown()
}
