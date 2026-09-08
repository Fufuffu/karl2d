package ui

import k2 "../../.."
import "base:runtime"
import "core:fmt"
import "core:math"

Rect :: k2.Rect
Vec2 :: k2.Vec2
Color :: k2.Color

ANIMATION_DURATION :: f32(0.2)
HOVER_DURATION :: f32(0.1)
SCROLLBAR_WIDTH :: f32(12)
SCROLLBAR_MIN_THUMB :: f32(20)
CLIP_STACK_SIZE :: 16
MAX_WINDOWS :: 16

FONT_SIZE_DEF: f32 : 20.0
COLOR_DEF :: Color{0, 0, 0, 0}
CORNER_BOX: f32 : 1

Horizontal_Alignment :: enum {
	Left,
	Center,
	Right,
}

Vertical_Aligment :: enum {
	Top,
	Center,
	Bottom,
}

Button_State :: enum {
	Idle,
	Pressed,
	Released,
}

Window_Option :: enum {
	Pinned,
	Resizable,
	Undecorated,
	Borderless,
	No_Padding,
}

Window_Options :: bit_set[Window_Option]

Window :: struct {
	id:       u64,
	rect:     Rect,
	min_size: Vec2,
	options:  Window_Options,
}

UI_Animation :: struct {
	widget:     uintptr,
	t:          f32,
	value_key0: f32,
	value_key1: f32,
}

UI_Hover :: struct {
	widget: uintptr,
	t:      f32,
}

Theme :: struct {
	window_skin:                                                         Skin,
	panel_skin:                                                          Skin,
	button_skin:                                                         Skin,
	toggle_thumb_skin, scrollbar_thumb_skin:                             Skin,
	slider_bar:                                                          Bar_Style,
	toggle_bar:                                                          Bar_Style,
	segmented_selection:                                                 Three_Slice,
	progress_bar:                                                        Bar_Style,
	scrollbar_track, scrollbar_thumb, scrollbar_hover, scrollbar_active: Color,
	window_border:                                                       Color,
	window_bg:                                                           Color,
	title_bg:                                                            Color,
	title_text:                                                          Color,
	panel_bg:                                                            Color,
	widget_bg:                                                           Color,
	widget_hover:                                                        Color,
	widget_active:                                                       Color,
	text:                                                                Color,
	accent:                                                              Color,
	separator:                                                           Color,
}

Scroll_State :: struct {
	offset_y:       f32,
	content_height: f32,
}

UI_Context :: struct {
	camera:                   Maybe(k2.Camera),
	slice_shader:             k2.Shader,
	slice_shader_ok:          bool,
	mouse_pos:                Vec2,
	mouse_button:             Button_State,
	mouse_down:               b32,
	padding:                  f32,
	corner:                   f32,
	font_height:              f32,
	row_height:               f32,
	theme:                    Theme,
	button_id:                uintptr,
	animation:                UI_Animation,
	hover:                    UI_Hover,
	dragging_object:          uintptr,
	dragging_offset:          Vec2,
	panel_depth:              int,
	current_clip:             Rect,
	clip_stack:               [CLIP_STACK_SIZE]Rect,
	clip_depth:               int,
	active_scroll:            ^Scroll_State,
	scroll_drag_start_y:      f32,
	scroll_drag_start_offset: f32,
	scroll_delta:             f32,
	windows:                  [MAX_WINDOWS]Window,
	num_windows:              int,
	current_window:           ^Window,
	resizing_window:          ^Window,
	rendered_rects:           [MAX_WINDOWS]Rect,
	num_rendered_rects:       int,
}

// -------- Library lifecycle management ----------
init :: proc(padding: f32, corner: f32, allocator := context.allocator) -> ^UI_Context {
	ui_context := new(UI_Context, allocator = allocator)

	ui_context.mouse_button = .Idle
	ui_context.padding = max(padding, 2.0)
	ui_context.corner = max(corner, 2.0)
	ui_context.font_height = k2.measure_text("A", FONT_SIZE_DEF).y
	ui_context.row_height = ui_context.font_height * 1.5
	ui_context.theme = Theme {
		scrollbar_track  = {192, 204, 215, 255},
		scrollbar_thumb  = {69, 89, 111, 255},
		scrollbar_hover  = {48, 72, 101, 255},
		scrollbar_active = {33, 56, 84, 255},
		window_border    = Color{0xB0, 0xCC, 0xE7, 0xFF},
		window_bg        = Color{0xF2, 0xF6, 0xFA, 0xFF},
		title_bg         = Color{0xD8, 0xE6, 0xF4, 0xFF},
		title_text       = Color{0x2C, 0x3E, 0x55, 0xFF},
		panel_bg         = Color{0xF2, 0xF6, 0xFA, 0xFF},
		widget_bg        = Color{0xD8, 0xE6, 0xF4, 0xFF},
		widget_hover     = Color{0xC3, 0xDB, 0xEE, 0xFF},
		widget_active    = Color{0xB0, 0xCC, 0xE7, 0xFF},
		text             = Color{0x2C, 0x3E, 0x55, 0xFF},
		accent           = Color{0x3E, 0x8B, 0xE5, 0xFF},
		separator        = Color{0x2C, 0x3E, 0x55, 0x40},
	}

	when k2.RENDER_BACKEND_NAME == "d3d11" {
		ui_context.slice_shader, ui_context.slice_shader_ok = k2.load_shader_from_bytes(
			#load("nine_slice.hlsl"),
			#load("nine_slice.hlsl"),
		)
	} else when k2.RENDER_BACKEND_NAME == "gl" {
		ui_context.slice_shader, ui_context.slice_shader_ok = k2.load_shader_from_bytes(
			#load("nine_slice_gl.vert"),
			#load("nine_slice_gl.frag"),
		)
	} else when k2.RENDER_BACKEND_NAME == "webgl" {
		ui_context.slice_shader, ui_context.slice_shader_ok = k2.load_shader_from_bytes(
			#load("nine_slice_webgl.vert"),
			#load("nine_slice_webgl.frag"),
		)
	}
	return ui_context
}

update_mouse_pos :: proc(ui_context: ^UI_Context, pos: Vec2) {
	ui_context.mouse_pos = pos
}

update_mouse_button :: proc(ui_context: ^UI_Context, state: Button_State) {
	ui_context.mouse_button = state

	if state == .Pressed {
		ui_context.mouse_down = true
	} else {
		if state == .Released {
			ui_context.mouse_down = false
		}
	}
}

update_scroll_delta :: proc(ui_context: ^UI_Context, delta: f32) {
	ui_context.scroll_delta = delta
}

begin_frame :: proc(ui_context: ^UI_Context, dt: f32) {
	assert(ui_context.current_window == nil)
	ui_context.num_rendered_rects = 0
	ui_context.button_id = 1 // 0 is reserved as "no widget"
	ui_context.animation.t = min(1.0, ui_context.animation.t + dt / ANIMATION_DURATION)
	ui_context.hover.t = min(1.0, ui_context.hover.t + dt / HOVER_DURATION)
}

end_frame :: proc(ui_context: ^UI_Context) {
	assert(ui_context.current_window == nil)
	if ui_context.animation.t >= 1.0 {
		ui_context.animation.widget = 0
	}

	if ui_context.mouse_button == .Released {
		ui_context.dragging_object = 0
		ui_context.active_scroll = nil
		ui_context.resizing_window = nil
	}
	ui_context.scroll_delta = 0
	ui_context.mouse_button = .Idle
}

// -------- Layout functions ----------
// Use a stable, unique name and lay out widgets from the returned content rect each frame.
begin_window :: proc(
	ui_context: ^UI_Context,
	name: string,
	rect: Rect,
	options: Window_Options = {},
) -> Rect {
	assert(ui_context.current_window == nil)
	assert(ui_context.clip_depth == 0)
	assert(ui_context.panel_depth == 0)
	assert(ui_context.num_rendered_rects < MAX_WINDOWS)

	id := hash_name(name)
	for &window in ui_context.windows[:ui_context.num_windows] {
		if window.id == id {
			ui_context.current_window = &window
			break
		}
	}
	if ui_context.current_window == nil {
		assert(ui_context.num_windows < MAX_WINDOWS)
		ui_context.current_window = &ui_context.windows[ui_context.num_windows]
		ui_context.num_windows += 1
		ui_context.current_window^ = Window {
			id       = id,
			rect     = rect,
			min_size = {
				k2.measure_text(name, FONT_SIZE_DEF).x + ui_context.padding * 2,
				ui_context.row_height * 2,
			},
			options  = options,
		}
	}

	window := ui_context.current_window
	window_id := uintptr(rawptr(window))
	if .Pinned in window.options do window.rect = rect

	handle_rect := Rect {
		window.rect.x + window.rect.w - ui_context.corner,
		window.rect.y + window.rect.h - ui_context.corner,
		ui_context.corner,
		ui_context.corner,
	}
	handle_hit_size := max(ui_context.corner, ui_context.font_height)
	handle_hit_rect := Rect {
		window.rect.x + window.rect.w - handle_hit_size,
		window.rect.y + window.rect.h - handle_hit_size,
		handle_hit_size,
		handle_hit_size,
	}
	if .Resizable in window.options &&
	   ui_context.mouse_button == .Pressed &&
	   is_mouse_in_rect(ui_context, handle_hit_rect) &&
	   ui_context.dragging_object == 0 &&
	   ui_context.active_scroll == nil &&
	   ui_context.resizing_window == nil {
		ui_context.resizing_window = window
		ui_context.dragging_offset =
			Vec2{window.rect.x + window.rect.w, window.rect.y + window.rect.h} -
			ui_context.mouse_pos
	}
	if ui_context.mouse_down && ui_context.resizing_window == window {
		window.rect.w = max(
			ui_context.mouse_pos.x + ui_context.dragging_offset.x - window.rect.x,
			window.min_size.x,
		)
		window.rect.h = max(
			ui_context.mouse_pos.y + ui_context.dragging_offset.y - window.rect.y,
			window.min_size.y,
		)
	}

	title_rect := Rect {
		window.rect.x + ui_context.padding,
		window.rect.y + ui_context.padding,
		window.rect.w - ui_context.padding * 2,
		ui_context.row_height,
	}
	if .Undecorated not_in window.options && .Pinned not_in window.options {
		if ui_context.mouse_button == .Pressed &&
		   is_mouse_in_rect(ui_context, title_rect) &&
		   ui_context.dragging_object == 0 &&
		   ui_context.resizing_window == nil &&
		   ui_context.active_scroll == nil {
			ui_context.dragging_object = window_id
			ui_context.dragging_offset = ui_context.mouse_pos - Vec2{window.rect.x, window.rect.y}
		}
		if ui_context.mouse_down && ui_context.dragging_object == window_id {
			pos := ui_context.mouse_pos - ui_context.dragging_offset
			window.rect.x = pos.x
			window.rect.y = pos.y
		}
	}

	// border
	if ui_context.theme.window_skin.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, window.rect, ui_context.theme.window_skin)
	} else if .Borderless not_in window.options {
		draw_rounded_rect(window.rect, ui_context.corner * 0.5, ui_context.theme.window_border)
	}

	bg_rect := window.rect
	if .Undecorated in window.options {
		if .No_Padding not_in window.options do cut_inset(&bg_rect, ui_context.padding, ui_context.padding)
	} else {
		title_rect.x = window.rect.x + ui_context.padding
		title_rect.y = window.rect.y + ui_context.padding

		// title background and text
		draw_rounded_rect(title_rect, ui_context.corner, ui_context.theme.title_bg)
		draw_text_align(ui_context, title_rect, name, ui_context.theme.title_text)
		cut_inset(&bg_rect, ui_context.padding, ui_context.padding)
		cut_top(&bg_rect, ui_context.row_height + ui_context.padding)
	}

	// content background
	if ui_context.theme.window_skin.texture.handle == k2.TEXTURE_NONE {
		draw_rounded_rect(bg_rect, ui_context.corner, ui_context.theme.window_bg)
	}
	content_rect := bg_rect
	if .No_Padding not_in window.options do cut_inset(&content_rect, ui_context.padding, ui_context.padding)
	content_rect.w = max(0, content_rect.w)
	content_rect.h = max(0, content_rect.h)

	// resize handle
	if .Resizable in window.options {
		handle_rect.x = window.rect.x + window.rect.w - handle_rect.w
		handle_rect.y = window.rect.y + window.rect.h - handle_rect.h
		draw_rounded_rect(handle_rect, 0, ui_context.theme.separator)
	}

	ui_context.rendered_rects[ui_context.num_rendered_rects] = window.rect
	ui_context.num_rendered_rects += 1
	push_clip_rect(ui_context, content_rect)
	return content_rect
}

end_window :: proc(ui_context: ^UI_Context) {
	assert(ui_context.current_window != nil)
	assert(ui_context.panel_depth == 0)
	assert(ui_context.clip_depth == 1)
	pop_clip_rect(ui_context)
	ui_context.current_window = nil
}

cut_left :: proc(rect: ^Rect, width: f32) -> Rect {
	result := Rect{rect.x, rect.y, width, rect.h}

	rect.x += width
	rect.w -= width

	return result
}

cut_right :: proc(rect: ^Rect, width: f32) -> Rect {
	result := Rect{rect.x + rect.w - width, rect.y, width, rect.h}

	rect.w -= width

	return result
}

cut_top :: proc(rect: ^Rect, height: f32) -> Rect {
	result := Rect{rect.x, rect.y, rect.w, height}

	rect.y += height
	rect.h -= height

	return result
}

cut_bottom :: proc(rect: ^Rect, height: f32) -> Rect {
	result := Rect{rect.x, rect.y + rect.h - height, rect.w, height}

	rect.h -= height

	return result
}

cut_inset :: proc(rect: ^Rect, padding_h: f32, padding_v: f32) {
	rect.x += padding_h
	rect.y += padding_v
	rect.w -= padding_h * 2
	rect.h -= padding_v * 2

	// TODO: Do we want to clamp rect.w and rect.h?
}

cut_row :: proc(rect: ^Rect, row_height: f32, padding: f32) -> Rect {
	result := cut_top(rect, row_height)
	cut_top(rect, padding)
	return result
}

cut_column :: proc(rect: ^Rect, col_width: f32, padding: f32) -> Rect {
	result := cut_left(rect, col_width)
	cut_left(rect, padding)
	return result
}

cut_standard_row :: proc(ui_context: ^UI_Context, rect: ^Rect) -> Rect {
	return cut_row(rect, ui_context.row_height, ui_context.padding)
}

cut_standard_col :: proc(ui_context: ^UI_Context, rect: ^Rect, col_width: f32) -> Rect {
	return cut_column(rect, col_width, ui_context.padding)
}

// -------- Widgets ----------
panel :: proc(ui_context: ^UI_Context, rect: Rect, inset_padding: f32, skin := Skin{}) -> Rect {
	darken_factor := max(1 - f32(ui_context.panel_depth + 1) * 0.05, 0.7)
	panel_color := ui_context.theme.panel_bg
	for i in 0 ..< 3 do panel_color[i] = u8(f32(panel_color[i]) * darken_factor)

	// panel background
	chosen := skin
	if chosen.texture.handle == k2.TEXTURE_NONE do chosen = ui_context.theme.panel_skin
	if chosen.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, rect, chosen)
	} else {
		draw_rounded_rect(rect, ui_context.corner, panel_color)
	}
	ui_context.panel_depth += 1
	content_rect := rect
	cut_inset(&content_rect, inset_padding, inset_padding)
	return content_rect
}

panel_end :: proc(ui_context: ^UI_Context) {
	assert(ui_context.panel_depth > 0)
	ui_context.panel_depth -= 1
}

begin_scroll :: proc(ui_context: ^UI_Context, viewport: Rect, state: ^Scroll_State) -> Rect {
	state.offset_y = clamp(state.offset_y, 0, max(0, state.content_height - viewport.h))

	// content clip, leaving room for the scrollbar
	content_rect := viewport
	if state.content_height > viewport.h do content_rect.w = max(0, content_rect.w - SCROLLBAR_WIDTH)
	push_clip_rect(ui_context, content_rect)
	content_rect.y -= state.offset_y
	content_rect.h = state.content_height
	return content_rect
}

end_scroll :: proc(ui_context: ^UI_Context, viewport: Rect, state: ^Scroll_State) {
	pop_clip_rect(ui_context)
	if state.content_height <= viewport.h || viewport.h <= 0 do return

	id := uintptr(rawptr(state))
	max_offset := state.content_height - viewport.h
	track := Rect {
		viewport.x + viewport.w - SCROLLBAR_WIDTH,
		viewport.y,
		SCROLLBAR_WIDTH,
		viewport.h,
	}

	// scrollbar track
	draw_rounded_rect(track, ui_context.corner, ui_context.theme.scrollbar_track)
	thumb_h := min(
		viewport.h,
		max(SCROLLBAR_MIN_THUMB, viewport.h * viewport.h / state.content_height),
	)
	scroll_range := viewport.h - thumb_h
	thumb := Rect {
		track.x,
		viewport.y + state.offset_y / max_offset * scroll_range,
		track.w,
		thumb_h,
	}
	hovering_thumb := is_mouse_in_rect(ui_context, thumb)
	hovering_track := is_mouse_in_rect(ui_context, track)

	if is_mouse_in_rect(ui_context, viewport) && ui_context.scroll_delta != 0 {
		state.offset_y = clamp(
			state.offset_y - ui_context.scroll_delta * viewport.h * 0.1,
			0,
			max_offset,
		)
		ui_context.scroll_delta = 0
		if ui_context.animation.widget == id do ui_context.animation.widget = 0
	}

	if ui_context.active_scroll == state && ui_context.mouse_down {
		dy := ui_context.mouse_pos.y - ui_context.scroll_drag_start_y
		delta := dy / scroll_range * max_offset if scroll_range > 0 else 0
		state.offset_y = clamp(ui_context.scroll_drag_start_offset + delta, 0, max_offset)
	} else if ui_context.mouse_button == .Pressed &&
	   hovering_thumb &&
	   ui_context.dragging_object == 0 {
		ui_context.active_scroll = state
		ui_context.scroll_drag_start_y = ui_context.mouse_pos.y
		ui_context.scroll_drag_start_offset = state.offset_y
		if ui_context.animation.widget == id do ui_context.animation.widget = 0
	} else if ui_context.mouse_button == .Pressed &&
	   hovering_track &&
	   ui_context.dragging_object == 0 {
		target_y := clamp(
			ui_context.mouse_pos.y - thumb_h * 0.5,
			viewport.y,
			viewport.y + scroll_range,
		)
		ui_context.animation = UI_Animation {
			widget     = id,
			value_key0 = state.offset_y,
			value_key1 = (target_y - viewport.y) / scroll_range * max_offset if scroll_range > 0 else 0,
		}
	}
	if ui_context.animation.widget == id {
		state.offset_y = clamp(
			lerp_float(
				ui_context.animation.value_key0,
				ui_context.animation.value_key1,
				ui_context.animation.t,
			),
			0,
			max_offset,
		)
	}

	// scrollbar thumb
	thumb.y = viewport.y + state.offset_y / max_offset * scroll_range
	thumb_color :=
		ui_context.theme.scrollbar_active if ui_context.active_scroll == state else (ui_context.theme.scrollbar_hover if hovering_thumb else ui_context.theme.scrollbar_thumb)
	if ui_context.theme.scrollbar_thumb_skin.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, thumb, ui_context.theme.scrollbar_thumb_skin, thumb_color)
	} else {
		draw_rounded_rect(thumb, ui_context.corner, thumb_color)
	}
	// Small grip marks remain visible on short thumbs and at camera zoom.
	grips := [?]f32{-3, 0, 3}
	for offset in grips {
		draw_rounded_rect(
			{thumb.x + 3, thumb.y + thumb.h * 0.5 + offset, thumb.w - 6, 1},
			0,
			ui_context.theme.scrollbar_track,
		)
	}
}

button :: proc(ui_context: ^UI_Context, rect: Rect) -> bool {
	rect := rect
	id := ui_context.button_id
	ui_context.button_id += 1

	clicked := false
	button_color := ui_context.theme.widget_bg

	if ui_context.animation.widget == id {
		button_color = lerp_color(
			ui_context.theme.accent,
			ui_context.theme.widget_bg,
			ease_in_expo(ui_context.animation.t),
		)
		expand_rect(&rect, -ease_impulse(ui_context.animation.t) * 2)
	} else if is_mouse_in_rect(ui_context, rect) {
		if ui_context.mouse_button == .Pressed && ui_context.animation.widget == 0 {
			clicked = true
			ui_context.animation = UI_Animation {
				widget = id,
			}
		} else if ui_context.hover.widget == id {
			button_color = lerp_color(
				ui_context.theme.widget_bg,
				ui_context.theme.widget_hover,
				ui_context.hover.t,
			)
		} else {
			ui_context.hover = UI_Hover {
				widget = id,
			}
		}
	} else if ui_context.hover.widget == id {
		ui_context.hover.widget = 0
	}

	if ui_context.theme.button_skin.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, rect, ui_context.theme.button_skin, button_color)
	} else {
		draw_rounded_rect(rect, ui_context.corner, ui_context.theme.separator)
		expand_rect(&rect, -1)
		draw_rounded_rect(rect, ui_context.corner, button_color)
	}

	return clicked
}

button_label :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	text: string,
	hor_align := Horizontal_Alignment.Center,
	ver_align := Vertical_Aligment.Center,
) -> bool {
	pressed := button(ui_context, rect)
	label(ui_context, rect, text, hor_align = hor_align, ver_align = ver_align)
	return pressed
}

toggle :: proc(ui_context: ^UI_Context, rect: Rect, label_text: string, value: ^bool) {
	id := uintptr(rawptr(value))
	font_height := ui_context.font_height
	content_rect := Rect{rect.x, rect.y, rect.w, ui_context.row_height}

	// label
	draw_text_align(
		ui_context,
		content_rect,
		label_text,
		ui_context.theme.text,
		hor_align = .Left,
		ver_align = .Center,
	)

	track_rect := Rect {
		content_rect.x + content_rect.w - font_height * 2 - ui_context.padding,
		content_rect.y + ui_context.padding,
		font_height * 2,
		font_height,
	}
	track_hovered := is_mouse_in_rect(ui_context, track_rect)
	if track_hovered && ui_context.mouse_button == .Pressed {
		value^ = !value^
		ui_context.animation = UI_Animation {
			widget     = id,
			value_key0 = track_rect.x + font_height + 2,
			value_key1 = track_rect.x + 2,
		}
	}

	thumb_rect := Rect {
		track_rect.x + font_height + 2 if value^ else track_rect.x + 2,
		track_rect.y + 2,
		font_height - 4,
		font_height - 4,
	}
	toggle_fill: f32 = 1 if value^ else 0
	track_color := ui_context.theme.accent if value^ else ui_context.theme.separator
	if ui_context.animation.widget == id {
		t := 1 - ui_context.animation.t if value^ else ui_context.animation.t
		thumb_rect.x = lerp_float(
			ui_context.animation.value_key0,
			ui_context.animation.value_key1,
			t,
		)
		track_color = lerp_color(ui_context.theme.accent, ui_context.theme.separator, t)
		toggle_fill = 1 - t
	}

	// track
	if bar_style_enabled(ui_context.theme.toggle_bar) {
		bar_rect := track_rect
		bar_rect.h = min(track_rect.h, bar_style_height(ui_context.theme.toggle_bar))
		bar_rect.y += (track_rect.h - bar_rect.h) * 0.5
		draw_bar(
			ui_context,
			bar_rect,
			toggle_fill,
			ui_context.theme.toggle_bar,
			ui_context.theme.separator,
			ui_context.theme.accent,
		)
	} else {
		draw_rounded_rect(track_rect, track_rect.h * 0.5, track_color)
	}

	// thumb
	if track_hovered do expand_rect(&thumb_rect, 1)
	if ui_context.theme.toggle_thumb_skin.texture.handle != k2.TEXTURE_NONE {
		thumb_skin := ui_context.theme.toggle_thumb_skin
		source := thumb_skin.source
		if source.w == 0 && source.h == 0 do source = k2.get_texture_rect(thumb_skin.texture)
		// Fit the round artwork without distorting its built-in lower shadow.
		if source.w > 0 && source.h > 0 {
			size := min(thumb_rect.w / source.w, thumb_rect.h / source.h)
			w, h := source.w * size, source.h * size
			thumb_rect.x += (thumb_rect.w - w) * 0.5
			thumb_rect.y += (thumb_rect.h - h) * 0.5
			thumb_rect.w, thumb_rect.h = w, h
		}
		tint := Color{205, 215, 240, 255} if track_hovered && ui_context.mouse_down else k2.WHITE
		draw_skin(ui_context, thumb_rect, thumb_skin, tint)
	} else {
		draw_rounded_rect(thumb_rect, thumb_rect.h * 0.5, ui_context.theme.text)
	}
}

segmented :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	entries: []string,
	selected: ^u32,
	font_size: f32 = 14,
) {
	if len(entries) == 0 || rect.w <= 0 || rect.h <= 0 do return
	id := uintptr(rawptr(selected))
	segment_width := rect.w / f32(len(entries))
	textured := ui_context.theme.segmented_selection.texture.handle != k2.TEXTURE_NONE
	// Use the supplied row for the panel and hit area, but keep the blue bar
	// at its native source height instead of stretching it to font metrics.
	highlight_height := max(0, rect.h - 8)
	if textured do highlight_height = min(highlight_height, ui_context.theme.segmented_selection.source[1].h)
	highlight_y := rect.y + (rect.h - highlight_height) * 0.5
	if ui_context.theme.panel_skin.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, rect, ui_context.theme.panel_skin)
	} else {
		draw_rounded_rect(rect, ui_context.corner, ui_context.theme.widget_bg)
	}
	if int(selected^) < len(entries) {
		x := rect.x + segment_width * f32(selected^)
		if ui_context.animation.widget == id {
			x = lerp_float(
				ui_context.animation.value_key0,
				ui_context.animation.value_key1,
				ease_out_back(ui_context.animation.t),
			)
		}
		highlight := Rect {
			x + ui_context.padding,
			highlight_y,
			max(0, segment_width - 2 * ui_context.padding),
			highlight_height,
		}
		if textured {
			draw_three_slice(ui_context, highlight, ui_context.theme.segmented_selection)
		} else {
			draw_rounded_rect(highlight, ui_context.padding, ui_context.theme.accent)
		}
	}
	for entry, i in entries {
		hit := Rect{rect.x + f32(i) * segment_width, rect.y, segment_width, rect.h}
		if is_mouse_in_rect(ui_context, hit) {
			if ui_context.mouse_button == .Pressed {
				ui_context.animation = {
					widget     = id,
					value_key0 = rect.x + segment_width * f32(selected^),
					value_key1 = hit.x,
				}
				selected^ = u32(i)
			} else if u32(i) != selected^ {
				hover_rect := Rect {
					hit.x + ui_context.padding,
					highlight_y,
					max(0, segment_width - 2 * ui_context.padding),
					highlight_height,
				}
				if textured {
					draw_three_slice(
						ui_context,
						hover_rect,
						ui_context.theme.segmented_selection,
						{255, 255, 255, 100},
					)
				} else {
					draw_rounded_rect(
						hover_rect,
						ui_context.padding,
						ui_context.theme.widget_hover,
					)
				}
			}
		}
		text_height := min(font_size, max(1, highlight_height - 4))
		measured := k2.measure_text(entry, text_height)
		available := max(0, segment_width - 2 * ui_context.padding - 8)
		if measured.x > available && measured.x > 0 do text_height *= available / measured.x
		if text_height > 0 do draw_text_align(ui_context, hit, entry, ui_context.theme.text, text_height)
		if i > 0 do draw_rounded_rect({hit.x - 0.5, rect.y + 6, 1, max(0, rect.h - 12)}, 0, ui_context.theme.separator)
	}
}

image :: proc(ui_context: ^UI_Context, rect: Rect, texture: k2.Texture) {
	k2.draw_texture_fit(texture, k2.get_texture_rect(texture), rect)
}

slider :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	label_text: string,
	min_value, max_value, step: f32,
	value: ^f32,
	fmt_str: string = "%.2f",
	bar_style := Bar_Style{},
) {
	style := bar_style
	if !bar_style_enabled(style) do style = ui_context.theme.slider_bar

	assert(max_value > min_value)

	id := uintptr(rawptr(value))
	value^ = clamp(value^, min_value, max_value)

	// first row, label and formatted value
	label_rect := Rect{rect.x, rect.y, rect.w, ui_context.row_height}
	draw_text_align(
		ui_context,
		label_rect,
		label_text,
		ui_context.theme.text,
		hor_align = .Left,
		ver_align = .Center,
	)
	draw_text_align(
		ui_context,
		label_rect,
		fmt.tprintf(fmt_str, value^),
		ui_context.theme.text,
		hor_align = .Right,
		ver_align = .Center,
	)

	// track + thumb row
	center_y := rect.y + ui_context.row_height * 1.5 + ui_context.padding
	track_height := bar_style_height(style) if bar_style_enabled(style) else ui_context.padding
	track_rect := Rect {
		rect.x + rect.w * 0.1,
		center_y - track_height * 0.5,
		rect.w * 0.8,
		track_height,
	}

	norm_value := (value^ - min_value) / (max_value - min_value)
	thumb_x := norm_value * track_rect.w + track_rect.x
	thumb_size := ui_context.font_height
	textured_thumb := style.thumb.texture.handle != k2.TEXTURE_NONE
	if textured_thumb do thumb_size = max(thumb_size, track_height + 10)
	thumb_width := thumb_size
	if textured_thumb {
		source := style.thumb.source
		if source.w == 0 && source.h == 0 do source = k2.get_texture_rect(style.thumb.texture)
		if source.h > 0 do thumb_width = thumb_size * source.w / source.h
	}
	half_size := thumb_size * 0.5

	thumb_rect := Rect{thumb_x - thumb_width * 0.5, center_y - half_size, thumb_width, thumb_size}

	track_hit_rect := Rect{track_rect.x, center_y - half_size, track_rect.w, thumb_size}
	track_hovered := is_mouse_in_rect(ui_context, track_hit_rect)
	thumb_hovered := is_mouse_in_rect(ui_context, thumb_rect)

	track_color :=
		ui_context.theme.widget_hover if (track_hovered || ui_context.dragging_object == id) else ui_context.theme.widget_bg

	if thumb_hovered {
		expand_rect(&thumb_rect, 2)
		if ui_context.mouse_button == .Pressed {
			ui_context.dragging_object = id
			ui_context.dragging_offset.x = ui_context.mouse_pos.x - thumb_x
		}
	} else if track_hovered && ui_context.mouse_button == .Pressed {
		ui_context.animation = UI_Animation {
			widget     = id,
			value_key0 = thumb_x,
			value_key1 = ui_context.mouse_pos.x,
		}
		if ui_context.dragging_object == id do ui_context.dragging_object = 0
	}

	if ui_context.animation.widget == id {
		thumb_x = lerp_float(
			ui_context.animation.value_key0,
			ui_context.animation.value_key1,
			ui_context.animation.t,
		)
	}

	if ui_context.mouse_down && ui_context.dragging_object == id {
		thumb_x = ui_context.mouse_pos.x - ui_context.dragging_offset.x
	}

	thumb_x = clamp(thumb_x, track_rect.x, track_rect.x + track_rect.w)
	norm_value = (thumb_x - track_rect.x) / track_rect.w
	value^ = norm_value * (max_value - min_value) + min_value
	if step > 0 do value^ = clamp(min_value + math.round((value^ - min_value) / step) * step, min_value, max_value)
	thumb_rect.x =
		track_rect.x +
		(value^ - min_value) / (max_value - min_value) * track_rect.w -
		thumb_rect.w * 0.5

	draw_bar(
		ui_context,
		track_rect,
		(value^ - min_value) / (max_value - min_value),
		style,
		track_color,
		ui_context.theme.accent,
		filled = bar_style_enabled(style),
	)

	if textured_thumb {
		tint := Color{205, 215, 240, 255} if ui_context.dragging_object == id else k2.WHITE
		draw_skin(ui_context, thumb_rect, style.thumb, tint)
	} else {
		draw_rounded_rect(thumb_rect, half_size, ui_context.theme.accent)
	}
}

progress_bar :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	label_text: string,
	min_value, max_value, value: f32,
	fmt_str: string = "%.2f",
	bar_style := Bar_Style{},
) {
	style := bar_style
	if !bar_style_enabled(style) do style = ui_context.theme.progress_bar

	assert(max_value > min_value)

	value := clamp(value, min_value, max_value)
	content_rect := Rect{rect.x, rect.y, rect.w, ui_context.row_height}

	label_size := k2.measure_text(label_text, FONT_SIZE_DEF)
	label_space := max(label_size.x + ui_context.padding * 2, content_rect.w * 0.20)

	draw_text_align(
		ui_context,
		content_rect,
		label_text,
		ui_context.theme.text,
		hor_align = .Left,
		ver_align = .Center,
	)

	bar_height := bar_style_height(style) if bar_style_enabled(style) else ui_context.padding * 3
	bg_rect := Rect {
		content_rect.x + label_space,
		content_rect.y + content_rect.h * 0.5 - bar_height * 0.5,
		content_rect.w - label_space,
		bar_height,
	}

	draw_bar(
		ui_context,
		bg_rect,
		(value - min_value) / (max_value - min_value),
		style,
		ui_context.theme.widget_bg,
		ui_context.theme.accent,
	)

	draw_text_align(
		ui_context,
		Rect{bg_rect.x, content_rect.y, bg_rect.w, content_rect.h},
		fmt.tprintf(fmt_str, value),
		ui_context.theme.text,
		hor_align = .Center,
		ver_align = .Center,
	)
}

label :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	text: string,
	font_size := FONT_SIZE_DEF,
	hor_align := Horizontal_Alignment.Center,
	ver_align := Vertical_Aligment.Center,
	color := COLOR_DEF,
) {
	color := color
	if color == COLOR_DEF do color = ui_context.theme.text

	draw_text_align(ui_context, rect, text, color, font_size, hor_align, ver_align)
}

separator :: proc(ui_context: ^UI_Context, rect: Rect) {
	y := rect.y + (rect.h / 2)
	draw_rounded_rect(Rect{rect.x, y, rect.w, 1}, CORNER_BOX, ui_context.theme.separator)
}

// -------- Utils ----------
hash_name :: proc(name: string) -> u64 {
	hash: u64 = 0xcbf29ce484222325
	for byte in transmute([]u8)name do hash = (hash ~ u64(byte)) * 0x100000001b3
	return hash
}

push_clip_rect :: proc(ui_context: ^UI_Context, rect: Rect) {
	assert(ui_context.clip_depth < len(ui_context.clip_stack))
	ui_context.clip_stack[ui_context.clip_depth] = ui_context.current_clip
	ui_context.clip_depth += 1

	clip_rect := rect
	if ui_context.clip_depth > 1 {
		outer := ui_context.current_clip
		x1 := min(clip_rect.x + clip_rect.w, outer.x + outer.w)
		y1 := min(clip_rect.y + clip_rect.h, outer.y + outer.h)
		clip_rect.x = max(clip_rect.x, outer.x)
		clip_rect.y = max(clip_rect.y, outer.y)
		clip_rect.w = max(0, x1 - clip_rect.x)
		clip_rect.h = max(0, y1 - clip_rect.y)
	}
	ui_context.current_clip = clip_rect
	set_clip_rect(ui_context.current_clip, camera = ui_context.camera)
}

pop_clip_rect :: proc(ui_context: ^UI_Context) {
	assert(ui_context.clip_depth > 0)
	ui_context.clip_depth -= 1
	ui_context.current_clip = ui_context.clip_stack[ui_context.clip_depth]
	set_clip_rect(
		ui_context.current_clip,
		enabled = ui_context.clip_depth > 0,
		camera = ui_context.camera,
	)
}

is_point_in_any_window :: proc(ui_context: ^UI_Context, point: Vec2) -> bool {
	for rect in ui_context.rendered_rects[:ui_context.num_rendered_rects] {
		if k2.point_in_rect(point, rect) do return true
	}
	return false
}

is_mouse_in_rect :: proc(ui_context: ^UI_Context, rect: Rect) -> bool {
	if ui_context.clip_depth > 0 {
		if !k2.point_in_rect(ui_context.mouse_pos, ui_context.current_clip) do return false
	}
	return k2.point_in_rect(ui_context.mouse_pos, rect)
}

expand_rect :: #force_inline proc(rect: ^Rect, amount: f32) {
	rect.x -= amount
	rect.y -= amount
	rect.w += amount * 2
	rect.h += amount * 2
}

// -------- Drawing utils ----------
// UI clips remain in logical coordinates for intersection and hit testing.
// Only the final scissor is converted to drawable pixels.
clip_to_screen :: proc(rect: Rect, camera: Maybe(k2.Camera)) -> Rect {
	if cam, ok := camera.?; ok {
		a := k2.camera_to_screen({rect.x, rect.y}, cam)
		b := k2.camera_to_screen({rect.x + rect.w, rect.y + rect.h}, cam)
		return {min(a.x, b.x), min(a.y, b.y), abs(b.x - a.x), abs(b.y - a.y)}
	}
	return rect
}

// Axis-aligned cameras preserve rectangular scissors exactly. Set between frames.
set_camera :: proc(ui_context: ^UI_Context, camera: Maybe(k2.Camera)) {
	assert(ui_context.clip_depth == 0)
	if cam, ok := camera.?; ok do assert(cam.rotation == 0 && cam.zoom >= 0)
	ui_context.camera = camera
	k2.set_camera(camera)
}

update_mouse_screen_pos :: proc(ui_context: ^UI_Context, position: Vec2) {
	if cam, ok := ui_context.camera.?; ok {
		update_mouse_pos(ui_context, k2.screen_to_camera(position, cam))
	} else {
		update_mouse_pos(ui_context, position)
	}
}

set_clip_rect :: proc(rect: Rect, enabled := true, camera: Maybe(k2.Camera) = nil) {
	if enabled {
		k2.set_scissor_rect(clip_to_screen(rect, camera))
	} else {
		k2.set_scissor_rect(nil)
	}
}

draw_text_align :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	text: string,
	color: Color,
	font_size := FONT_SIZE_DEF,
	hor_align := Horizontal_Alignment.Center,
	ver_align := Vertical_Aligment.Center,
) {
	text_size := k2.measure_text(text, font_size)

	text_pos: Vec2
	switch hor_align {
	case .Left:
		text_pos.x = rect.x
	case .Center:
		text_pos.x = rect.x + (rect.w / 2) - (text_size.x / 2)
	case .Right:
		text_pos.x = rect.x + rect.w - text_size.x
	}

	switch ver_align {
	case .Top:
		text_pos.y = rect.y
	case .Center:
		text_pos.y = rect.y + (rect.h / 2) - (text_size.y / 2)
	case .Bottom:
		text_pos.y = rect.y + rect.h - text_size.y
	}

	k2.draw_text(text, text_pos, font_size, color)
}

draw_rounded_rect :: proc(rect: Rect, corner: f32, color: Color) {
	min_size := min(rect.w, rect.h)
	if min_size <= 0 do return
	roundness := clamp(corner * 2 / min_size, 0, 1)
	k2.draw_rect_rounded(rect, roundness, color)
}

// -------- Animation helpers ----------
lerp_float :: #force_inline proc(a, b, t: f32) -> f32 {return a + (b - a) * t}

lerp_color :: #force_inline proc(a, b: Color, t: f32) -> Color {
	return Color {
		u8(f32(a[0]) + (f32(b[0]) - f32(a[0])) * t),
		u8(f32(a[1]) + (f32(b[1]) - f32(a[1])) * t),
		u8(f32(a[2]) + (f32(b[2]) - f32(a[2])) * t),
		u8(f32(a[3]) + (f32(b[3]) - f32(a[3])) * t),
	}
}

ease_in_cubic :: #force_inline proc(x: f32) -> f32 {return x * x * x}
ease_out_back :: #force_inline proc(x: f32) -> f32 {
	c1: f32 : 0.8
	c3 := c1 + 1
	return 1 + c3 * ease_in_cubic(x - 1) + c1 * (x - 1) * (x - 1)
}
ease_impulse :: #force_inline proc(x: f32) -> f32 {return ease_in_cubic(math.sin(x * math.PI))}
ease_in_expo :: #force_inline proc(x: f32) -> f32 {
	return 0 if x == 0 else math.pow(f32(2), 10 * x - 10)
}
