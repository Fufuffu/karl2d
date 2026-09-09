package textured_ui

import k2 "../.."
import ui "ui"

backpack_viewport, journal_viewport, settings_viewport: k2.Rect
smoke_window: k2.Rect
smoke_pace: f32

rect_center :: proc(rect: k2.Rect) -> k2.Vec2 {
	return {rect.x + rect.w * 0.5, rect.y + rect.h * 0.5}
}

// Scripted input exercises the example through its normal frame loop.
smoke_input :: proc(frame: int) {
	ctx.mouse_button = .Idle
	ctx.mouse_down = false
	ctx.mouse_pos = {-10000, -10000}
	ctx.scroll_delta = 0
	switch frame {
	case 1:
		ctx.mouse_pos = rect_center(journal_viewport)
		ctx.scroll_delta = -3
	case 2:
		ctx.mouse_pos = rect_center(backpack_viewport)
		ctx.scroll_delta = -3
	case 3:
		settings_open = true
	case 4:
		ctx.mouse_pos = rect_center(settings_viewport)
		ctx.scroll_delta = -3
	case 5:
		// A modal blocks clicks on the expedition button.
		ctx.mouse_pos = rect_center(travel_control)
		ctx.mouse_button = .Pressed
	case 6:
		settings_scroll.offset_y = 0
	case 7:
		smoke_window = settings_rect
		ctx.mouse_pos = {settings_rect.x + settings_rect.w * 0.5, settings_rect.y + ctx.padding + ctx.row_height * 0.5}
		ui.update_mouse_button(ctx, .Pressed)
	case 8:
		ctx.mouse_pos = {smoke_window.x + smoke_window.w * 0.5 + 30, smoke_window.y + ctx.padding + ctx.row_height * 0.5 + 20}
		ctx.mouse_down = true
	case 9:
		ui.update_mouse_button(ctx, .Released)
	case 10:
		smoke_window = settings_rect
		ctx.mouse_pos = {
			settings_rect.x + settings_rect.w - 2,
			settings_rect.y + settings_rect.h - 2,
		}
		ui.update_mouse_button(ctx, .Pressed)
	case 11:
		ctx.mouse_pos = {
			settings_rect.x + settings_rect.w + 30,
			settings_rect.y + settings_rect.h + 20,
		}
		ctx.mouse_down = true
	case 12:
		ui.update_mouse_button(ctx, .Released)
	case 13:
		settings_open = false
	case 14:
		ctx.mouse_pos = rect_center(map_control)
		ui.update_mouse_button(ctx, .Pressed)
	case 15:
		ctx.animation = {}
		ctx.mouse_pos = rect_center(travel_control)
		ui.update_mouse_button(ctx, .Pressed)
	case 16:
		settings_open = true
	case 17:
		ctx.mouse_pos = {
			collect_control.x + collect_control.w - ctx.padding - ctx.font_height,
			collect_control.y + ctx.padding + ctx.font_height * 0.5,
		}
		ui.update_mouse_button(ctx, .Pressed)
	case 18:
		ui.update_mouse_button(ctx, .Released)
	case 19:
		smoke_pace = pace
		ctx.animation = {}
		ctx.mouse_pos = {
			speed_control.x + speed_control.w * 0.85,
			speed_control.y + ctx.row_height * 1.5 + ctx.padding,
		}
		ui.update_mouse_button(ctx, .Pressed)
	case 20:
		ctx.animation.t = 1
	case 21:
		ui.update_mouse_button(ctx, .Released)
	case 22:
		settings_open = false
	}
}

smoke_verify :: proc(frame: int) {
	assert(ctx.clip_depth == 0 && ctx.panel_depth == 0 && ctx.current_window == nil)
	switch frame {
	case 1:
		assert(journal_scroll.offset_y > 0 && backpack_scroll.offset_y == 0)
	case 2:
		assert(backpack_scroll.offset_y > 0)
	case 4:
		assert(settings_scroll.offset_y > 0)
	case 5:
		assert(!travelling)
	case 8:
		assert(settings_rect.x > smoke_window.x && settings_rect.y > smoke_window.y)
	case 11:
		assert(settings_rect.w > smoke_window.w && settings_rect.h > smoke_window.h)
	case 14:
		assert(selected_place == 3)
	case 15:
		assert(travelling)
	case 17:
		assert(!auto_collect)
	case 20:
		assert(pace > smoke_pace)
	}
}
