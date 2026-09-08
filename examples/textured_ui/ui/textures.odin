package ui

// Atlas rectangles and borders are in source pixels; border_scale converts them
// to UI units. Zero borders give an ordinary stretched texture. Textures remain
// caller-owned. Keep the source rectangle within the texture, without flips.
Skin :: struct {
    texture: k2.Texture,
    source: Rect,
    borders: [4]f32, // left, top, right, bottom
    border_scale: f32,
}

import k2 "../../.."
import "core:math"

destroy :: proc(ui_context: ^UI_Context, allocator := context.allocator) {
    if ui_context.slice_shader_ok do k2.destroy_shader(ui_context.slice_shader)
    free(ui_context, allocator)
}

draw_skin :: proc(ui_context: ^UI_Context, rect: Rect, skin: Skin, tint := k2.WHITE) {
    if rect.w <= 0 || rect.h <= 0 || skin.texture.handle == k2.TEXTURE_NONE do return
    src := skin.source
    if src.w == 0 && src.h == 0 do src = k2.get_texture_rect(skin.texture)
    assert(src.x >= 0 && src.y >= 0 && src.w > 0 && src.h > 0)
    assert(src.x + src.w <= f32(skin.texture.width) && src.y + src.h <= f32(skin.texture.height))
    b := skin.borders
    for v in b do assert(v >= 0)
    assert(b[0] + b[2] <= src.w && b[1] + b[3] <= src.h)
    scale := skin.border_scale if skin.border_scale > 0 else 1
    if ui_context.slice_shader_ok {
        sh := ui_context.slice_shader
        k2.set_shader_constant(sh, sh.constant_lookup["source_rect"], [4]f32{src.x, src.y, src.w, src.h})
        k2.set_shader_constant(sh, sh.constant_lookup["borders"], b)
        k2.set_shader_constant(sh, sh.constant_lookup["destination"], [4]f32{rect.w, rect.h, scale, 0})
        k2.set_shader_constant(sh, sh.constant_lookup["atlas_size"], [2]f32{f32(skin.texture.width), f32(skin.texture.height)})
        k2.set_shader(sh)
        k2.draw_texture_fit(skin.texture, k2.get_texture_rect(skin.texture), rect, tint = tint)
        k2.set_shader(nil)
    } else {
        // Portable fallback when shader compilation fails. Shrink opposing
        // borders together for destinations smaller than their combined size.
        sx := min(scale, rect.w / max(b[0] + b[2], 0.0001))
        sy := min(scale, rect.h / max(b[1] + b[3], 0.0001))
        xx := [4]f32{src.x, src.x+b[0], src.x+src.w-b[2], src.x+src.w}
        yy := [4]f32{src.y, src.y+b[1], src.y+src.h-b[3], src.y+src.h}
        dx := [4]f32{rect.x, rect.x+b[0]*sx, rect.x+rect.w-b[2]*sx, rect.x+rect.w}
        dy := [4]f32{rect.y, rect.y+b[1]*sy, rect.y+rect.h-b[3]*sy, rect.y+rect.h}
        for y in 0..<3 {
            for x in 0..<3 {
                if dx[x+1] <= dx[x] || dy[y+1] <= dy[y] || xx[x+1] <= xx[x] || yy[y+1] <= yy[y] do continue
                k2.draw_texture_fit(skin.texture, {xx[x], yy[y], xx[x+1]-xx[x], yy[y+1]-yy[y]},
                    {dx[x], dy[y], dx[x+1]-dx[x], dy[y+1]-dy[y]}, tint = tint)
            }
        }
    }
}

// Atlas image widget; participates in the same scissor state as other widgets.
image_region :: proc(ui_context: ^UI_Context, rect: Rect, texture: k2.Texture, source: Rect, tint := k2.WHITE) {
    if rect.w <= 0 || rect.h <= 0 do return
    k2.draw_texture_fit(texture, source, rect, tint = tint)
}

// Three noncontiguous atlas regions: left cap, stretched middle, right cap.
// Cap widths follow the rendered bar height, so artwork scales with UI units.
Three_Slice :: struct {
    texture: k2.Texture,
    source: [3]Rect,
}

Bar_Style :: struct {
    track, fill: Three_Slice,
    thumb: Skin, // optional slider handle; unused by progress bars
    height: f32, // logical units; zero uses 18
}

bar_style_enabled :: proc(style: Bar_Style) -> bool {
    return style.track.texture.handle != k2.TEXTURE_NONE || style.fill.texture.handle != k2.TEXTURE_NONE || style.thumb.texture.handle != k2.TEXTURE_NONE
}

bar_style_height :: proc(style: Bar_Style) -> f32 {
    return style.height if style.height > 0 else 18
}

// Preserve the cap proportions, including bars too narrow for both full caps.
three_slice_widths :: proc(source: [3]Rect, width, height: f32) -> [3]f32 {
    for rect in source do assert(rect.w > 0 && rect.h > 0)
    if width <= 0 || height <= 0 do return {}
    left := source[0].w * height/source[0].h
    right := source[2].w * height/source[2].h
    fit := min(1,width/(left+right))
    left *= fit
    right *= fit
    return {left,max(0,width-left-right),right}
}

// Align shared slice boundaries in framebuffer pixels, then return to logical
// units. This avoids half-pixel filtering on caps without changing UI input.
snap_texture_rect :: proc(ui_context: ^UI_Context, rect: Rect) -> Rect {
    a,b := Vec2{rect.x,rect.y},Vec2{rect.x+rect.w,rect.y+rect.h}
    if camera,ok := ui_context.camera.?; ok {
        a,b = k2.camera_to_screen(a,camera),k2.camera_to_screen(b,camera)
    }
    a,b = {math.round(a.x),math.round(a.y)},{math.round(b.x),math.round(b.y)}
    if camera,ok := ui_context.camera.?; ok {
        a,b = k2.screen_to_camera(a,camera),k2.screen_to_camera(b,camera)
    }
    return {min(a.x,b.x),min(a.y,b.y),abs(b.x-a.x),abs(b.y-a.y)}
}

draw_three_slice :: proc(ui_context: ^UI_Context, rect: Rect, bar: Three_Slice, tint := k2.WHITE) {
    if rect.w <= 0 || rect.h <= 0 || bar.texture.handle == k2.TEXTURE_NONE do return
    widths := three_slice_widths(bar.source,rect.w,rect.h)
    x := rect.x
    for source,i in bar.source {
        // Reuse the skin shader's half-texel clamping for each atlas region.
        piece := snap_texture_rect(ui_context,{x,rect.y,widths[i],rect.h})
        draw_skin(ui_context,piece,{texture=bar.texture,source=source},tint)
        x += widths[i]
    }
}

draw_bar :: proc(ui_context: ^UI_Context, rect: Rect, fraction: f32, style: Bar_Style,
    track_color, fill_color: Color, filled := true) {
    if rect.w <= 0 || rect.h <= 0 do return
    if style.track.texture.handle != k2.TEXTURE_NONE {
        draw_three_slice(ui_context,rect,style.track)
    } else {
        draw_rounded_rect(rect,rect.h*0.5,track_color)
    }
    fill := rect
    fill.w *= clamp(fraction,0,1)
    if !filled || fill.w <= 0 do return
    if style.fill.texture.handle != k2.TEXTURE_NONE {
        draw_three_slice(ui_context,fill,style.fill)
    } else {
        draw_rounded_rect(fill,fill.h*0.5,fill_color)
    }
}
