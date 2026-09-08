package ui

import "core:testing"
import k2 "../../.."

@(test)
three_slice_caps_fit_small_and_scaled_bars :: proc(t: ^testing.T) {
    source := [3]Rect{{370,90,9,18},{356,368,18,18},{190,348,9,18}}
    testing.expect(t,three_slice_widths(source,100,18)==[3]f32{9,82,9})
    testing.expect(t,three_slice_widths(source,200,36)==[3]f32{18,164,18})
    testing.expect(t,three_slice_widths(source,18,18)==[3]f32{9,0,9})
    testing.expect(t,three_slice_widths(source,4,18)==[3]f32{2,0,2})
    testing.expect(t,three_slice_widths(source,0,18)==[3]f32{})
    // Unequal caps retain their ratio when the fill is almost empty.
    asymmetric := [3]Rect{{0,0,6,18},{6,0,18,18},{24,0,12,18}}
    testing.expect(t,three_slice_widths(asymmetric,3,18)==[3]f32{1,0,2})
}

@(test)
bar_slices_share_pixel_aligned_edges :: proc(t: ^testing.T) {
    ctx := UI_Context{camera=k2.Camera{zoom=1.25,offset={13.2,7.6}}}
    left := snap_texture_rect(&ctx,{10.3,20.5,9,18})
    middle := snap_texture_rect(&ctx,{19.3,20.5,80.2,18})
    testing.expect(t,abs(left.x+left.w-middle.x)<0.0001)
    testing.expect(t,abs(left.y-middle.y)<0.0001 && abs(left.h-middle.h)<0.0001)
    screen := clip_to_screen(left,ctx.camera)
    testing.expect(t,abs(screen.x-26)<0.0001 && abs(screen.y-33)<0.0001)
    testing.expect(t,abs(screen.w-11)<0.0001 && abs(screen.h-23)<0.0001)
}
