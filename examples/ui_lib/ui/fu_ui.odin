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
	widget_bg:     Color,
	widget_hover:  Color,
	widget_active: Color,
	text:          Color,
	accent:        Color,
	separator:     Color,
}

UI_Context :: struct {
	mouse_pos:       Vec2,
	mouse_button:    Button_State,
	mouse_down:      b32,
	padding:         f32,
	corner:          f32,
	font_height:     f32,
	row_height:      f32,
	theme:           Theme,
	button_id:       uintptr,
	animation:       UI_Animation,
	hover:           UI_Hover,
	dragging_object: uintptr,
	dragging_offset: Vec2,
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
		widget_bg     = Color{0xD8, 0xE6, 0xF4, 0xFF},
		widget_hover  = Color{0xC3, 0xDB, 0xEE, 0xFF},
		widget_active = Color{0xB0, 0xCC, 0xE7, 0xFF},
		text          = Color{0x2C, 0x3E, 0x55, 0xFF},
		accent        = Color{0x3E, 0x8B, 0xE5, 0xFF},
		separator     = Color{0x2C, 0x3E, 0x55, 0x40},
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

begin_frame :: proc(ui_context: ^UI_Context, dt: f32) {
	ui_context.button_id = 1 // 0 is reserved as "no widget"
	ui_context.animation.t = min(1.0, ui_context.animation.t + dt / ANIMATION_DURATION)
	ui_context.hover.t = min(1.0, ui_context.hover.t + dt / HOVER_DURATION)
}

end_frame :: proc(ui_context: ^UI_Context) {
	if ui_context.animation.t >= 1.0 {
		ui_context.animation.widget = 0
	}

	if ui_context.mouse_button == .Released {
		ui_context.dragging_object = 0
	}
	ui_context.mouse_button = .Idle
}

// -------- Layout functions ----------
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
	} else if k2.point_in_rect(ui_context.mouse_pos, rect) {
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

	draw_rounded_rect(rect, ui_context.corner, ui_context.theme.separator)
	expand_rect(&rect, -1)
	draw_rounded_rect(rect, ui_context.corner, button_color)

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
	track_hovered := k2.point_in_rect(ui_context.mouse_pos, track_rect)
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
	track_color := ui_context.theme.accent if value^ else ui_context.theme.separator
	if ui_context.animation.widget == id {
		t := 1 - ui_context.animation.t if value^ else ui_context.animation.t
		thumb_rect.x = lerp_float(ui_context.animation.value_key0, ui_context.animation.value_key1, t)
		track_color = lerp_color(ui_context.theme.accent, ui_context.theme.separator, t)
	}

	// track
	draw_rounded_rect(track_rect, track_rect.h * 0.5, track_color)

	// thumb
	if track_hovered do expand_rect(&thumb_rect, 1)
	draw_rounded_rect(thumb_rect, thumb_rect.h * 0.5, ui_context.theme.text)
}

segmented :: proc(ui_context: ^UI_Context, rect: Rect, entries: []string, selected: ^u32) {
	if len(entries) == 0 do return

	id := uintptr(rawptr(selected))
	content_rect := Rect{rect.x, rect.y, rect.w, ui_context.row_height}
	seg_rect := Rect {
		content_rect.x,
		content_rect.y,
		content_rect.w / f32(len(entries)),
		ui_context.font_height,
	}

	// background
	draw_rounded_rect(
		Rect{seg_rect.x, seg_rect.y + ui_context.padding, content_rect.w, seg_rect.h},
		ui_context.corner,
		ui_context.theme.widget_bg,
	)

	// selected segment
	if int(selected^) < len(entries) {
		x := seg_rect.x + seg_rect.w * f32(selected^)
		if ui_context.animation.widget == id {
			x = lerp_float(
				ui_context.animation.value_key0,
				ui_context.animation.value_key1,
				ease_out_back(ui_context.animation.t),
			)
		}
		draw_rounded_rect(
			Rect {
				x + ui_context.padding,
				seg_rect.y + ui_context.padding,
				seg_rect.w - 2 * ui_context.padding,
				seg_rect.h,
			},
			ui_context.padding,
			ui_context.theme.accent,
		)
	}

	for entry, i in entries {
		button_rect := seg_rect
		button_rect.y += ui_context.padding
		if k2.point_in_rect(ui_context.mouse_pos, button_rect) {
			if ui_context.mouse_button == .Pressed {
				ui_context.animation = UI_Animation {
					widget     = id,
					value_key0 = content_rect.x + seg_rect.w * f32(selected^),
					value_key1 = content_rect.x + seg_rect.w * f32(i),
				}
				selected^ = u32(i)
			} else if u32(i) != selected^ {
				// hovered segment
				draw_rounded_rect(button_rect, ui_context.padding, ui_context.theme.widget_hover)
			}
		}

		// segment label
		draw_text_align(ui_context, button_rect, entry, ui_context.theme.text)

		// separator
		if i > 0 {
			draw_rounded_rect(
				Rect {
					seg_rect.x - 0.5,
					seg_rect.y + ui_context.padding * 2,
					1,
					seg_rect.h - 2 * ui_context.padding,
				},
				CORNER_BOX,
				ui_context.theme.separator,
			)
		}
		seg_rect.x += seg_rect.w
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
) {
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
	track_rect := Rect {
		rect.x + rect.w * 0.1,
		center_y - ui_context.padding * 0.5,
		rect.w * 0.8,
		ui_context.padding,
	}

	norm_value := (value^ - min_value) / (max_value - min_value)
	thumb_x := norm_value * track_rect.w + track_rect.x
	thumb_size := ui_context.font_height - 4
	half_size := thumb_size * 0.5

	thumb_rect := Rect{thumb_x - half_size, center_y - half_size, thumb_size, thumb_size}

	track_hovered := k2.point_in_rect(ui_context.mouse_pos, track_rect)
	thumb_hovered := k2.point_in_rect(ui_context.mouse_pos, thumb_rect)

	track_color :=
		ui_context.theme.widget_hover if (track_hovered || ui_context.dragging_object == id) else ui_context.theme.widget_bg
	draw_rounded_rect(track_rect, track_rect.h * 0.5, track_color)

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
	if step > 0 do value^ = math.round(value^ / step) * step

	draw_rounded_rect(thumb_rect, half_size, ui_context.theme.accent)
}

progress_bar :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	label_text: string,
	min_value, max_value, value: f32,
	fmt_str: string = "%.2f",
) {
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

	bg_rect := Rect {
		content_rect.x + label_space,
		content_rect.y + content_rect.h * 0.5 - ui_context.padding * 1.5,
		content_rect.w - label_space,
		ui_context.padding * 3,
	}

	draw_rounded_rect(bg_rect, bg_rect.h * 0.5, ui_context.theme.widget_bg)

	filled_width := (value - min_value) / (max_value - min_value) * bg_rect.w
	if filled_width > 0 {
		draw_rounded_rect(
			Rect{bg_rect.x, bg_rect.y, filled_width, bg_rect.h},
			bg_rect.h * 0.5,
			ui_context.theme.accent,
		)
	}

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
expand_rect :: #force_inline proc(rect: ^Rect, amount: f32) {
	rect.x -= amount
	rect.y -= amount
	rect.w += amount * 2
	rect.h += amount * 2
}

// -------- Drawing utils ----------
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
	k2.draw_rect_rounded(rect, corner, color)
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
