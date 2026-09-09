#+build !js

package ui

import k2 "../../.."
import "core:testing"

@(test)
camera_clip_and_input_use_same_logical_space :: proc(t: ^testing.T) {
    // Includes fractional DPI, a 4K framebuffer, and portrait letterboxing.
    sizes := [?]Vec2{{1280,800},{1600,1000},{3840,2160},{900,1600}}
    for size in sizes {
        cam := k2.Camera{target={640,400},offset=size*0.5,zoom=min(size.x/1280,size.y/800)}
        clip := clip_to_screen({100,200,300,150},cam)
        expected := (Vec2{100,200}-cam.target)*cam.zoom+cam.offset
        testing.expect(t,abs(clip.x-expected.x)<0.01 && abs(clip.y-expected.y)<0.01)
        testing.expect(t,abs(clip.w-300*cam.zoom)<0.01 && abs(clip.h-150*cam.zoom)<0.01)
        ctx := UI_Context{camera=cam,clip_depth=1,current_clip={100,200,300,150}}
        update_mouse_screen_pos(&ctx,k2.camera_to_screen({250,275},cam))
        testing.expect(t,is_mouse_in_rect(&ctx,{0,0,1280,800}),"inside scissor remains interactive")
        update_mouse_screen_pos(&ctx,k2.camera_to_screen({250,351},cam))
        testing.expect(t,!is_mouse_in_rect(&ctx,{0,0,1280,800}),"clipped content cannot receive input")
    }
}

@(test)
uncamered_ui_preserves_screen_coordinates :: proc(t: ^testing.T) {
    rect := Rect{11,22,33,44}
    testing.expect(t,clip_to_screen(rect,nil)==rect)
    ctx: UI_Context
    update_mouse_screen_pos(&ctx,{19,27})
    testing.expect(t,ctx.mouse_pos==Vec2{19,27})
    // Empty intersections must stay empty after scaling.
    result := clip_to_screen({10,20,0,0},k2.Camera{zoom=2,offset={30,40}})
    testing.expect(t,result==Rect{50,80,0,0})
}
