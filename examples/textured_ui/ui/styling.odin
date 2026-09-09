package ui

import k2 "../../.."

draw_window_frame :: proc(ui_context: ^UI_Context, window: ^Window) {
	if ui_context.theme.window_skin.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, window.rect, ui_context.theme.window_skin)
	} else if .Borderless not_in window.options {
		draw_rounded_rect(window.rect, ui_context.corner * 0.5, ui_context.theme.window_border)
	}
}

draw_window_content :: proc(ui_context: ^UI_Context, bg_rect: Rect) {
	if ui_context.theme.window_skin.texture.handle == k2.TEXTURE_NONE {
		draw_rounded_rect(bg_rect, ui_context.corner, ui_context.theme.window_bg)
	}
}

draw_panel_background :: proc(ui_context: ^UI_Context, rect: Rect, skin: Skin) {
	chosen := skin
	if chosen.texture.handle == k2.TEXTURE_NONE do chosen = ui_context.theme.panel_skin
	panel_color := ui_context.theme.panel_bg
	if chosen.texture.handle == k2.TEXTURE_NONE {
		darken_factor := max(1 - f32(ui_context.panel_depth + 1) * 0.05, 0.7)
		for i in 0 ..< 3 do panel_color[i] = u8(f32(panel_color[i]) * darken_factor)
	}
	draw_surface(ui_context, rect, chosen, ui_context.corner, panel_color)
}

draw_scrollbar_thumb :: proc(ui_context: ^UI_Context, thumb: Rect, thumb_color: Color) {
	draw_surface(ui_context, thumb, ui_context.theme.scrollbar_thumb_skin,
		ui_context.corner, thumb_color, thumb_color)
	// Keep grips visible on short thumbs.
	grips := [?]f32{-3, 0, 3}
	for offset in grips {
		draw_rounded_rect(
			{thumb.x + 3, thumb.y + thumb.h * 0.5 + offset, thumb.w - 6, 1},
			0,
			ui_context.theme.scrollbar_track,
		)
	}
}

draw_button_background :: proc(ui_context: ^UI_Context, rect: Rect, button_color: Color) {
	if ui_context.theme.button_skin.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, rect, ui_context.theme.button_skin, button_color)
	} else {
		draw_rounded_rect(rect, ui_context.corner, ui_context.theme.separator)
		inner := rect
		expand_rect(&inner, -1)
		draw_rounded_rect(inner, ui_context.corner, button_color)
	}
}

draw_toggle_track :: proc(ui_context: ^UI_Context, track_rect: Rect, toggle_fill: f32, track_color: Color) {
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
}

draw_surface :: proc(ui_context: ^UI_Context, rect: Rect, skin: Skin, corner: f32, color: Color, tint := k2.WHITE) {
	if skin.texture.handle != k2.TEXTURE_NONE {
		draw_skin(ui_context, rect, skin, tint)
	} else {
		draw_rounded_rect(rect, corner, color)
	}
}

draw_slice_surface :: proc(ui_context: ^UI_Context, rect: Rect, slices: Three_Slice, corner: f32, color: Color, tint := k2.WHITE) {
	if slices.texture.handle != k2.TEXTURE_NONE {
		draw_three_slice(ui_context, rect, slices, tint)
	} else {
		draw_rounded_rect(rect, corner, color)
	}
}

draw_round_thumb :: proc(ui_context: ^UI_Context, rect: Rect, skin: Skin, color: Color, active: bool) {
	thumb := rect
	if skin.texture.handle != k2.TEXTURE_NONE {
		source := skin_source(skin)
		scale := min(rect.w / source.w, rect.h / source.h)
		thumb.w, thumb.h = source.w * scale, source.h * scale
		thumb.x += (rect.w - thumb.w) * 0.5
		thumb.y += (rect.h - thumb.h) * 0.5
	}
	tint := Color{205, 215, 240, 255} if active else k2.WHITE
	draw_surface(ui_context, thumb, skin, rect.h * 0.5, color, tint)
}

slider_thumb_size :: proc(ui_context: ^UI_Context, style: Bar_Style, track_height: f32) -> Vec2 {
	height := ui_context.font_height
	if style.thumb.texture.handle != k2.TEXTURE_NONE {
		height = max(height, track_height + 10)
		source := skin_source(style.thumb)
		return {height * source.w / source.h, height}
	}
	return {height, height}
}

selection_height :: proc(ui_context: ^UI_Context, row_height: f32) -> f32 {
	height := max(0, row_height - 8)
	if ui_context.theme.segmented_selection.texture.handle != k2.TEXTURE_NONE {
		height = min(height, ui_context.theme.segmented_selection.source[1].h)
	}
	return height
}

draw_selection :: proc(ui_context: ^UI_Context, rect: Rect, hovered := false) {
	color := ui_context.theme.widget_hover if hovered else ui_context.theme.accent
	tint := Color{255, 255, 255, 100} if hovered else k2.WHITE
	draw_slice_surface(ui_context, rect, ui_context.theme.segmented_selection, ui_context.padding, color, tint)
}

draw_bar :: proc(
	ui_context: ^UI_Context,
	rect: Rect,
	fraction: f32,
	style: Bar_Style,
	track_color, fill_color: Color,
	filled := true,
) {
	if rect.w <= 0 || rect.h <= 0 do return
	draw_slice_surface(ui_context, rect, style.track, rect.h * 0.5, track_color)
	fill := rect
	fill.w *= clamp(fraction, 0, 1)
	if !filled || fill.w <= 0 do return
	draw_slice_surface(ui_context, fill, style.fill, fill.h * 0.5, fill_color)
}
