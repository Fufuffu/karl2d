package ui

import k2 "../../.."
import "core:math"

// Sources must be positive, unflipped rectangles within the borrowed texture.
// Borders are nonnegative source pixels and must fit inside the source.
// Zero borders stretch the image. Zero border_scale uses one UI unit per pixel.
Skin :: struct {
	texture:      k2.Texture,
	source:       Rect,
	borders:      [4]f32, // left, top, right, bottom
	border_scale: f32,
}

// Left cap, stretched middle, right cap, each with a positive source size.
Three_Slice :: struct {
	texture: k2.Texture,
	source:  [3]Rect,
}

Bar_Style :: struct {
	track, fill: Three_Slice,
	thumb:       Skin, // optional slider handle
	height:      f32, // UI units, zero uses 18
}

destroy :: proc(ui_context: ^UI_Context, allocator := context.allocator) {
	k2.destroy_shader(ui_context.slice_shader)
	free(ui_context, allocator)
}

load_slice_shader :: proc() -> k2.Shader {
	shader: k2.Shader
	ok: bool
	when k2.RENDER_BACKEND_NAME == "d3d11" {
		shader, ok = k2.load_shader_from_bytes(#load("nine_slice.hlsl"), #load("nine_slice.hlsl"))
	} else when k2.RENDER_BACKEND_NAME == "gl" || k2.RENDER_BACKEND_NAME == "webgl" {
		VERSION :: "#version 330\n" when k2.RENDER_BACKEND_NAME == "gl" else "#version 300 es\n"
		VERTEX :: VERSION + #load("nine_slice.vert", string)
		FRAGMENT :: VERSION + #load("nine_slice.frag", string)
		shader, ok = k2.load_shader_from_bytes(transmute([]u8)VERTEX, transmute([]u8)FRAGMENT)
	} else {
		#panic("Textured UI requires D3D11, GL, or WebGL")
	}
	assert(ok, "Failed to load the UI slice shader")
	return shader
}

skin_source :: proc(skin: Skin) -> Rect {
	if skin.source.w == 0 && skin.source.h == 0 do return k2.get_texture_rect(skin.texture)
	return skin.source
}

draw_skin :: proc(ui_context: ^UI_Context, rect: Rect, skin: Skin, tint := k2.WHITE) {
	if rect.w <= 0 || rect.h <= 0 do return
	source := skin_source(skin)
	scale := skin.border_scale if skin.border_scale > 0 else 1
	shader := ui_context.slice_shader
	k2.set_shader_constant(shader, shader.constant_lookup["source_rect"], [4]f32{source.x, source.y, source.w, source.h})
	k2.set_shader_constant(shader, shader.constant_lookup["source_borders"], skin.borders)
	k2.set_shader_constant(shader, shader.constant_lookup["dest_size_scale"], [4]f32{rect.w, rect.h, scale, 0})
	k2.set_shader_constant(shader, shader.constant_lookup["atlas_size"], [2]f32{f32(skin.texture.width), f32(skin.texture.height)})
	k2.set_shader(shader)
	k2.draw_texture_fit(skin.texture, k2.get_texture_rect(skin.texture), rect, tint = tint)
	k2.set_shader(nil)
}

image_region :: proc(ui_context: ^UI_Context, rect: Rect, texture: k2.Texture, source: Rect, tint := k2.WHITE) {
	if rect.w <= 0 || rect.h <= 0 do return
	k2.draw_texture_fit(texture, source, rect, tint = tint)
}

bar_style_enabled :: proc(style: Bar_Style) -> bool {
	return style.track.texture.handle != k2.TEXTURE_NONE || style.fill.texture.handle != k2.TEXTURE_NONE || style.thumb.texture.handle != k2.TEXTURE_NONE
}

bar_style_height :: proc(style: Bar_Style) -> f32 {
	return style.height if style.height > 0 else 18
}

// Preserve the cap proportions, including bars too narrow for both full caps.
three_slice_widths :: proc(source:  [3]Rect, width, height:      f32) -> [3]f32 {
	if width <= 0 || height <= 0 do return {}
	left := source[0].w * height / source[0].h
	right := source[2].w * height / source[2].h
	fit := min(1, width / (left + right))
	left *= fit
	right *= fit
	return {left, max(0, width - left - right), right}
}

// Snap shared boundaries in framebuffer pixels to avoid filtering seams.
snap_texture_rect :: proc(ui_context: ^UI_Context, rect: Rect) -> Rect {
	a, b := Vec2{rect.x, rect.y}, Vec2{rect.x + rect.w, rect.y + rect.h}
	if camera, ok := ui_context.camera.?; ok {
		a, b = k2.camera_to_screen(a, camera), k2.camera_to_screen(b, camera)
	}
	a, b = {math.round(a.x), math.round(a.y)}, {math.round(b.x), math.round(b.y)}
	if camera, ok := ui_context.camera.?; ok {
		a, b = k2.screen_to_camera(a, camera), k2.screen_to_camera(b, camera)
	}
	return {min(a.x, b.x), min(a.y, b.y), abs(b.x - a.x), abs(b.y - a.y)}
}

draw_three_slice :: proc(ui_context: ^UI_Context, rect: Rect, bar: Three_Slice, tint := k2.WHITE) {
	if rect.w <= 0 || rect.h <= 0 do return
	widths := three_slice_widths(bar.source, rect.w, rect.h)
	x := rect.x
	for source, i in bar.source {
		// Reuse the skin shader's half-texel clamping for each atlas region.
		piece := snap_texture_rect(ui_context, {x, rect.y, widths[i], rect.h})
		draw_skin(ui_context, piece, {texture = bar.texture, source = source}, tint)
		x += widths[i]
	}
}
