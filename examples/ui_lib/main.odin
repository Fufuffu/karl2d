package ui_lib

import k2 "../.."
import ui "ui"

INITIAL_WIDTH :: 1280
INITIAL_HEIGHT :: 720

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
popup_open: bool
popup_rect: k2.Rect
popup_enabled := true
popup_value: f32 = 50

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init :: proc() {
	k2.init(INITIAL_WIDTH, INITIAL_HEIGHT, "UI LIB", options = {window_mode = .Windowed_Resizable})
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

	k2.clear(ui_context.theme.window_bg)

	ui.begin_frame(ui_context, dt)
	if popup_open && (k2.point_in_rect(mouse_pos, popup_rect) ||
	   ui_context.dragging_object != 0 || ui_context.resizing_window != nil) {
		mouse_button := ui_context.mouse_button
		mouse_down := ui_context.mouse_down
		scroll_delta := ui_context.scroll_delta
		ui_context.mouse_pos = {-1, -1}
		ui_context.mouse_button = .Idle
		ui_context.mouse_down = false
		ui_context.scroll_delta = 0
		draw_ui()
		ui_context.mouse_pos = mouse_pos
		ui_context.mouse_button = mouse_button
		ui_context.mouse_down = mouse_down
		ui_context.scroll_delta = scroll_delta
	} else {
		draw_ui()
	}
	if popup_open do draw_popup()
	ui.end_frame(ui_context)

	k2.present()

	free_all(context.temp_allocator)
	return true
}

draw_ui :: proc() {
	window_size := k2.get_screen_size()
	fullscreen_rect := k2.Rect{0, 0, window_size.x, window_size.y}
	gap := min(window_size.x, window_size.y) * 0.025
	row_height := ui_context.row_height
	left_panel_rect := ui.cut_left(&fullscreen_rect, fullscreen_rect.w * 0.26)

	draw_page(fullscreen_rect, gap)
	ui.cut_inset(&left_panel_rect, gap, gap)
	left_panel_rect = ui.panel(ui_context, left_panel_rect, gap * 0.8)
	defer ui.panel_end(ui_context)

	row := ui.cut_row(&left_panel_rect, row_height * 1.4, ui_context.padding)
	ui.label(ui_context, row, "Quick controls", font_size = ui.FONT_SIZE_DEF * 1.2, hor_align = .Left)

	row = ui.cut_row(&left_panel_rect, ui_context.padding * 0.25, gap * 0.8)
	ui.separator(ui_context, row)

	row = ui.cut_row(&left_panel_rect, row_height * 1.3, gap * 0.8)
	ui.cut_inset(&row, ui_context.padding, ui_context.padding * 0.25)
	if ui.button_label(ui_context, row, "Open window") do popup_open = true

	slider_rect := ui.cut_row(
		&left_panel_rect,
		ui_context.row_height * 2 + ui_context.padding,
		ui_context.padding,
	)
	ui.cut_inset(&slider_rect, ui_context.padding, ui_context.padding * 0.25)
	ui.slider(ui_context, slider_rect, "Speed", 0, 100, 0.25, &slider_value)

	progress_rect := ui.cut_standard_row(ui_context, &left_panel_rect)
	ui.cut_inset(&progress_rect, ui_context.padding, ui_context.padding * 0.25)
	ui.progress_bar(ui_context, progress_rect, "Speed", 0, 100, slider_value)

	row = ui.cut_standard_row(ui_context, &left_panel_rect)
	ui.cut_inset(&row, ui_context.padding, ui_context.padding * 0.25)
	ui.toggle(ui_context, row, "Enabled", &toggle_value)

	row = ui.cut_standard_row(ui_context, &left_panel_rect)
	ui.cut_inset(&row, ui_context.padding, ui_context.padding * 0.25)
	ui.segmented(ui_context, row, segment_entries[:], &segment_selected)

	image_rect := ui.cut_row(&left_panel_rect, min(left_panel_rect.w * 0.75, max(0, left_panel_rect.h)), ui_context.padding)
	ui.cut_inset(&image_rect, ui_context.padding, ui_context.padding * 0.25)
	ui.image(ui_context, image_rect, image_texture)
}

draw_popup :: proc() {
	window_size := k2.get_screen_size()
	size := k2.Vec2{window_size.x * 0.35, max(window_size.y * 0.4, ui_context.row_height * 8)}
	initial_rect := k2.Rect{(window_size.x - size.x) * 0.5, (window_size.y - size.y) * 0.5, size.x, size.y}
	content := ui.begin_window(ui_context, "Quick settings", initial_rect, {.Resizable})
	defer ui.end_window(ui_context)
	popup_rect = ui_context.current_window.rect

	ui.label(ui_context, ui.cut_standard_row(ui_context, &content), "Drag the title bar to move", hor_align = .Left)
	content = ui.panel(ui_context, content, ui_context.padding * 2)
	defer ui.panel_end(ui_context)

	ui.toggle(ui_context, ui.cut_standard_row(ui_context, &content), "Enabled", &popup_enabled)
	slider_rect := ui.cut_row(&content, ui_context.row_height * 2 + ui_context.padding, ui_context.padding)
	ui.slider(ui_context, slider_rect, "Level", 0, 100, 1, &popup_value, "%.0f%%")
	if ui.button_label(ui_context, ui.cut_standard_row(ui_context, &content), "Close") do popup_open = false
}

draw_page :: proc(rect: k2.Rect, gap: f32) {
	rect := rect
	ui.cut_inset(&rect, gap, gap)
	row_height := ui_context.row_height
	page := ui.panel(ui_context, rect, gap)
	defer ui.panel_end(ui_context)

	ui.label(ui_context, ui.cut_row(&page, row_height * 1.4, ui_context.padding), "Mission control", font_size = ui.FONT_SIZE_DEF * 1.5, hor_align = .Left)
	ui.label(ui_context, ui.cut_row(&page, row_height, gap * 0.6), "Your workspace, tuned for the next adventure.", hor_align = .Left)
	ui.separator(ui_context, ui.cut_row(&page, ui_context.padding * 0.25, gap * 0.8))

	viewport := page
	image_height := viewport.w * 0.35
	section_heading := row_height * 1.1
	standard_row := row_height + ui_context.padding
	settings_height := gap * 1.6 + section_heading + gap * 0.6 + standard_row * 3 + row_height * 2 + ui_context.padding
	status_height := gap * 1.6 + section_heading + gap * 0.6 + standard_row * 3
	notes_height := gap * 1.6 + section_heading + gap * 0.6 + standard_row * 4
	intro_height := image_height + gap * 0.8 + row_height * 1.2 + ui_context.padding + row_height + gap
	sections_height := settings_height + status_height + notes_height + gap * 3
	footer_height := row_height * 1.3 + gap * 0.6 + standard_row
	page_scroll.content_height = ui_context.padding * 2 + intro_height + sections_height + footer_height
	content := ui.begin_scroll(ui_context, viewport, &page_scroll)
	ui.cut_inset(&content, 0, ui_context.padding)
	content.w = max(0, content.w - gap * 0.6)

	ui.image(ui_context, ui.cut_row(&content, image_height, gap * 0.8), image_texture)
	ui.label(ui_context, ui.cut_row(&content, row_height * 1.2, ui_context.padding), "Ready for launch", font_size = ui.FONT_SIZE_DEF * 1.3, hor_align = .Left)
	ui.label(ui_context, ui.cut_row(&content, row_height, gap), "Explore the controls below to make this space your own.", hor_align = .Left)

	settings := ui.panel(ui_context, ui.cut_row(&content, settings_height, gap), gap * 0.8)
	ui.label(ui_context, ui.cut_row(&settings, section_heading, gap * 0.6), "Preferences", font_size = ui.FONT_SIZE_DEF * 1.2, hor_align = .Left)
	ui.toggle(ui_context, ui.cut_standard_row(ui_context, &settings), "Notifications", &page_notifications)
	ui.label(ui_context, ui.cut_standard_row(ui_context, &settings), "Visual quality", hor_align = .Left)
	ui.segmented(ui_context, ui.cut_standard_row(ui_context, &settings), segment_entries[:], &page_quality)
	ui.slider(ui_context, settings, "Audio level", 0, 100, 1, &page_volume, "%.0f%%")
	ui.panel_end(ui_context)

	status := ui.panel(ui_context, ui.cut_row(&content, status_height, gap), gap * 0.8)
	ui.label(ui_context, ui.cut_row(&status, section_heading, gap * 0.6), "Launch checklist", font_size = ui.FONT_SIZE_DEF * 1.2, hor_align = .Left)
	ui.progress_bar(ui_context, ui.cut_standard_row(ui_context, &status), "Assets", 0, 100, 100, "%.0f%%")
	ui.progress_bar(ui_context, ui.cut_standard_row(ui_context, &status), "Systems", 0, 100, 75, "%.0f%%")
	ui.progress_bar(ui_context, ui.cut_standard_row(ui_context, &status), "Fuel", 0, 100, slider_value, "%.0f%%")
	ui.panel_end(ui_context)

	notes := ui.panel(ui_context, ui.cut_row(&content, notes_height, gap), gap * 0.8)
	ui.label(ui_context, ui.cut_row(&notes, section_heading, gap * 0.6), "Before you go", font_size = ui.FONT_SIZE_DEF * 1.2, hor_align = .Left)
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

	if ui.button_label(ui_context, ui.cut_row(&content, row_height * 1.3, gap * 0.6), "Reset preferences") {
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
