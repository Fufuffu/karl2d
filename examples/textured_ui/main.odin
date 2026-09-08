package textured_ui

import k2 "../.."
import "core:fmt"
import "core:math"
import ui "ui"

DESIGN :: k2.Vec2{1280, 800}
INK :: k2.Color{70, 61, 47, 255}
CREAM :: k2.Color{243, 230, 193, 255}
GOLD :: k2.Color{223, 177, 82, 255}
ctx: ^ui.UI_Context
atlas, portrait: k2.Texture
health_bar, mana_bar: ui.Bar_Style
backpack_scroll, journal_scroll, settings_scroll: ui.Scroll_State
category, stance: u32
selected_item: int
selected_place: int = 1
settings_open: bool
collect_control, speed_control, travel_control, map_control: k2.Rect
settings_rect := k2.Rect{410, 180, 460, 430}
auto_collect := true
show_routes := true
pace: f32 = 1
health: f32 = 82
mana: f32 = 64
travel: f32
travelling: bool
completed: int
coins := 125
notice := "Choose a destination, prepare your pack, then set out."

Item :: struct {
	name, detail: string,
	icon:         k2.Rect,
	category:     u32,
}
ITEMS := [?]Item {
	{"Wayfarer's blade", "+8 attack / equipped", {335, 152, 34, 37}, 1},
	{"Ember potion", "Restores 25 health", {370, 90, 9, 18}, 2},
	{"Moonwater", "Restores 30 mana", {372, 294, 9, 18}, 2},
	{"Old brass key", "Opens the watchtower", {338, 294, 34, 37}, 3},
	{"Leather gloves", "+2 defense", {0, 482, 30, 30}, 1},
	{"Silver gauntlet", "+5 defense", {60, 482, 30, 30}, 1},
	{"Forest tonic", "Restores 25 health", {370, 108, 9, 18}, 2},
	{"Guild seal", "Proof of membership", {335, 76, 35, 38}, 3},
	{"Ranger's knife", "+4 attack", {338, 331, 34, 37}, 1},
	{"Lucky coin", "A little extra luck", {369, 152, 17, 17}, 3},
	{"Travel gloves", "Warm and well worn", {30, 482, 30, 30}, 1},
	{"Sun elixir", "Restores 25 health", {370, 126, 9, 18}, 2},
}
PLACES := [?]string{"Hearthwick", "Whispering Wood", "Old Watchtower", "Moonlit Ruins"}
POINTS := [?]k2.Vec2{{0.20, 0.70}, {0.43, 0.48}, {0.76, 0.61}, {0.66, 0.20}}
QUESTS := [?]string {
	"A path through the pines",
	"The keeper's key",
	"Echoes in the ruins",
	"Supplies for the guild",
	"A blade worth keeping",
	"The missing courier",
	"A light at the tower",
}

skin :: proc(source: k2.Rect) -> ui.Skin {
	return {texture = atlas, source = source, borders = {8, 8, 8, 8}, border_scale = 1}
}
label :: proc(rect: k2.Rect, value: string, size: f32 = 16, color := INK) {
	ui.label(ctx, rect, value, font_size = size, color = color, hor_align = .Left)
}
row :: proc(rect: ^k2.Rect, height: f32 = 30, gap: f32 = 6) -> k2.Rect {
	return ui.cut_row(rect, height, gap)
}
button :: proc(rect: k2.Rect, value: string) -> bool {
	// Neutral tint preserves the original atlas colors for buttons only.
	saved := ctx.theme.widget_bg
	ctx.theme.widget_bg = k2.WHITE
	clicked := ui.button(ctx, rect)
	ctx.theme.widget_bg = saved
	ui.label(ctx, rect, value, font_size = 16, color = CREAM)
	return clicked
}

main :: proc() {
	k2.init(
		#config(UI_WIDTH, 1280),
		#config(UI_HEIGHT, 800),
		"Hearth & Hollow | camera UI playground",
		options = {window_mode = .Windowed_Resizable},
	)
	ctx = ui.init(6, 8)
	atlas = k2.load_texture_from_bytes(#load("assets/uipack_rpg_sheet.png"))
	portrait = k2.load_texture_from_bytes(#load("assets/portrait.png"))
	defer k2.shutdown()
	defer k2.destroy_texture(atlas)
	defer k2.destroy_texture(portrait)
	defer ui.destroy(ctx)
	ctx.theme.window_skin = skin({0, 376, 100, 100})
	ctx.theme.panel_skin = skin({200, 294, 93, 94})
	ctx.theme.button_skin = skin({0, 188, 190, 49})
	track := ui.Three_Slice {
		texture = atlas,
		source  = {{372, 330, 9, 18}, {338, 386, 18, 18}, {190, 294, 9, 18}},
	}
	health_bar = {
		track = track,
		fill = {
			texture = atlas,
			source = {{370, 90, 9, 18}, {356, 368, 18, 18}, {190, 348, 9, 18}},
		},
		height = 18,
	}
	mana_bar = {
		track = track,
		fill = {
			texture = atlas,
			source = {{372, 294, 9, 18}, {356, 431, 18, 18}, {372, 312, 9, 18}},
		},
		height = 18,
	}
	// One atlas material for all blue fills, including selector highlights.
	ctx.theme.progress_bar = mana_bar
	ctx.theme.toggle_bar = mana_bar
	ctx.theme.segmented_selection = mana_bar.fill
	ctx.theme.slider_bar = mana_bar
	ctx.theme.slider_bar.thumb = {
		texture = atlas,
		source  = {335, 38, 35, 38},
	}
	ctx.theme.toggle_thumb_skin = ctx.theme.slider_bar.thumb
	// The lower corner starts at source row 40; keep it and the button's
	// drop shadow inside the fixed cap, with one flat row before the curve.
	ctx.theme.scrollbar_thumb_skin = {
		texture = atlas,
		source  = {290, 0, 45, 49},
		borders = {4, 4, 4, 10},
	}
	ctx.theme.scrollbar_track = {167, 143, 98, 255}
	ctx.theme.scrollbar_thumb = {165, 180, 205, 255}
	ctx.theme.scrollbar_hover = {205, 215, 240, 255}
	ctx.theme.scrollbar_active = {145, 165, 200, 255}
	ctx.theme.text = INK
	ctx.theme.title_text = CREAM
	ctx.theme.title_bg = {101, 76, 49, 255}
	ctx.theme.widget_bg = {173, 151, 105, 255}
	ctx.theme.widget_hover = {207, 195, 167, 255}
	ctx.theme.widget_active = GOLD
	ctx.theme.accent = {45, 175, 218, 255} // shared blue for selections, progress, and active toggles
	ctx.theme.separator = {88, 71, 45, 110}
	frames := 0
	for k2.update() {
		size := k2.get_screen_size()
		if size.x <= 0 || size.y <= 0 do continue
		camera := k2.Camera {
			target = DESIGN * 0.5,
			offset = size * 0.5,
			zoom   = min(size.x / DESIGN.x, size.y / DESIGN.y),
		}
		ui.set_camera(ctx, camera)
		ui.update_mouse_screen_pos(ctx, k2.get_mouse_position())
		ui.update_scroll_delta(ctx, k2.get_mouse_wheel_delta())
		if k2.mouse_button_went_down(.Left) do ui.update_mouse_button(ctx, .Pressed)
		else if k2.mouse_button_went_up(.Left) do ui.update_mouse_button(ctx, .Released)
		dt := min(k2.get_frame_time(), 0.1)
		if travelling && !settings_open {
			travel = min(100, travel + dt * pace * (9 + f32(stance) * 3))
			if travel >= 100 {
				travelling = false
				completed += 1
				health = max(5, health - 8 - f32(stance) * 4)
				mana = max(0, mana - 6)
				if auto_collect do coins += 25
				notice = "Destination reached! Journal updated. Rest or explore again."
			}
		}
		when #config(UI_SMOKE_TEST, false) do smoke_input(frames, camera)
		ui.begin_frame(ctx, dt)
		k2.clear({31, 48, 51, 255})
		// A modal owns all input, even outside its bounds. Underlying windows
		// still draw and retain button order but cannot react to this gesture.
		mouse, state, down, wheel :=
			ctx.mouse_pos, ctx.mouse_button, ctx.mouse_down, ctx.scroll_delta
		if settings_open {
			ctx.mouse_pos = {-10000, -10000}
			ctx.mouse_button = .Idle
			ctx.mouse_down = false
			ctx.scroll_delta = 0
		}
		draw_game()
		ctx.mouse_pos, ctx.mouse_button, ctx.mouse_down, ctx.scroll_delta =
			mouse, state, down, wheel
		if settings_open {
			k2.draw_rect({0, 0, DESIGN.x, DESIGN.y}, {12, 21, 24, 170})
			draw_settings()
		}
		ui.end_frame(ctx)
		ui.set_camera(ctx, nil)
		k2.present()
		free_all(context.temp_allocator)
		when #config(UI_SMOKE_TEST, false) {
			smoke_verify(frames)
			frames += 1
			if frames == 23 do break
		}
	}
	when #config(UI_SMOKE_TEST, false) {
		assert(frames == 23)
		fmt.println(
			"PASS: 23 frames; camera, scrolling, modal, drag, resize, map, expedition, toggle and slider checks",
		)
	}
}

draw_game :: proc() {
	// The HUD demonstrates a pinned, undecorated, borderless window with no
	// padding. Its transparent background lets the scene color show through.
	window_skin, window_bg := ctx.theme.window_skin, ctx.theme.window_bg
	ctx.theme.window_skin, ctx.theme.window_bg = {}, {0, 0, 0, 0}
	ui.begin_window(
		ctx,
		"HUD",
		{24, 14, 1232, 64},
		{.Pinned, .Undecorated, .Borderless, .No_Padding},
	)
	ctx.theme.window_skin, ctx.theme.window_bg = window_skin, window_bg
	label({24, 14, 520, 38}, "HEARTH & HOLLOW", 28, CREAM)
	label(
		{26, 52, 570, 25},
		"WAYFARER'S GUILD  /  Expedition 07  /  Autumn, day 12",
		14,
		{170, 190, 181, 255},
	)
	label({870, 25, 190, 35}, fmt.tprintf("%d gold", coins), 20, GOLD)
	if button({1080, 22, 176, 42}, "Camp settings") do settings_open = true
	ui.end_window(ctx)
	draw_backpack()
	draw_expedition()
	draw_journal()
	label({26, 752, 1220, 25}, notice, 16, CREAM)
	label(
		{26, 777, 1220, 18},
		"Wheel: scroll  |  Map: choose destination  |  Settings: drag title / resize corner  |  UI rendered in camera units",
		12,
		{152, 175, 166, 255},
	)
}

draw_backpack :: proc() {
	content := ui.begin_window(ctx, "THE WAYFARER", {24, 92, 304, 644}, {.Pinned})
	defer ui.end_window(ctx)
	card := ui.panel(ctx, row(&content, 106), 10)
	icon_rect := ui.cut_left(&card, 62)
	ui.image(ctx, {icon_rect.x + 4, icon_rect.y + 6, 52, 64}, portrait)
	ui.cut_left(&card, 8)
	label(row(&card, 27), "Mira of Hearthwick", 18)
	label(row(&card, 22), "Ranger / Level 07", 14)
	label(row(&card, 20), "Ready for the road", 13)
	ui.panel_end(ctx)
	ui.progress_bar(ctx, row(&content, 30), "HP", 0, 100, health, "%.0f", bar_style = health_bar)
	ui.progress_bar(ctx, row(&content, 30), "MP", 0, 100, mana, "%.0f", bar_style = mana_bar)
	label(row(&content, 24), "BACKPACK", 16, CREAM)
	tabs := [?]string{"All", "Gear", "Aid", "Keys"}
	ui.segmented(ctx, row(&content, 36), tabs[:], &category)
	// Reserve the selected item's action before handing the middle to scrolling.
	action := ui.cut_bottom(&content, 74)
	ui.cut_bottom(&content, 8)
	viewport := ui.panel(ctx, content, 8)
	count := 0
	for item in ITEMS do if category == 0 || item.category == category do count += 1
	backpack_scroll.content_height = f32(count) * 62
	list := ui.begin_scroll(ctx, viewport, &backpack_scroll)
	for item, i in ITEMS {
		if category != 0 && item.category != category do continue
		item_rect := row(&list, 56, 6)
		if ui.is_mouse_in_rect(ctx, item_rect) && ctx.mouse_button == .Pressed do selected_item = i
		if selected_item == i do ui.draw_skin(ctx, item_rect, skin({190, 100, 100, 100}))
		icon_rect := ui.cut_left(&item_rect, 40)
		ui.image_region(ctx, {icon_rect.x + 7, icon_rect.y + 9, 26, 30}, atlas, item.icon)
		label({item_rect.x + 4, item_rect.y + 3, item_rect.w - 8, 24}, item.name, 14)
		label({item_rect.x + 4, item_rect.y + 27, item_rect.w - 8, 23}, item.detail, 11)
	}
	ui.end_scroll(ctx, viewport, &backpack_scroll)
	ui.panel_end(ctx)
	label(row(&action, 22, 4), ITEMS[selected_item].name, 14, CREAM)
	if button(action, "Use / equip selected") {
		if ITEMS[selected_item].category == 2 {
			if selected_item == 2 do mana = min(100, mana + 30)
			else do health = min(100, health + 25)
			notice = "Supplies used. Your resources have been restored."
		} else {
			notice = "Equipment readied. You're prepared for the next expedition."
		}
	}
}

draw_expedition :: proc() {
	content := ui.begin_window(ctx, "THE NORTHERN REACH", {342, 92, 576, 644}, {.Pinned})
	defer ui.end_window(ctx)
	map_rect := row(&content, 326, 10)
	draw_map(map_rect)
	info := ui.panel(ctx, content, 12)
	defer ui.panel_end(ctx)
	label(row(&info, 28), PLACES[selected_place], 23)
	label(row(&info, 22), "Explore the old road. Bring back a story and 25 gold.", 14)
	ui.separator(ctx, row(&info, 4, 8))
	stances := [?]string{"Cautious", "Balanced", "Bold"}
	ui.segmented(ctx, row(&info, 34), stances[:], &stance)
	ui.progress_bar(ctx, row(&info, 34), "Journey", 0, 100, travel, "%.0f%%")
	actions := row(&info, 42)
	rest := ui.cut_right(&actions, 116)
	ui.cut_right(&actions, 8)
	travel_control = actions
	if button(actions, "Return to camp" if travelling else "Begin expedition") {
		if travelling {
			travelling = false
			notice = "Returned to camp. Your next adventure can wait."
		} else {
			travelling = true
			travel = 0
			notice = "On the road. Journey speed and stance affect your expedition."
		}
	}
	if button(rest, "Rest") {
		health, mana = 100, 100
		travelling = false
		notice = "A quiet moment by the fire. Health and mana restored."
	}
}

draw_map :: proc(rect: k2.Rect) {
	map_rect := ui.panel(ctx, rect, 12)
	defer ui.panel_end(ctx)
	ui.push_clip_rect(ctx, map_rect)
	defer ui.pop_clip_rect(ctx)
	k2.draw_rect(map_rect, {75, 101, 83, 255})
	// Native geometry keeps the map sharp under camera zoom, like the text.
	for i in 0 ..< 25 {
		x := map_rect.x + f32((i * 73 + 21) % 510)
		y := map_rect.y + f32((i * 47 + 17) % 300)
		k2.draw_circle({x, y}, f32(24 + i % 4 * 7), {66, 91, 72, 255})
		k2.draw_triangle({{x, y - 16}, {x - 11, y + 10}, {x + 11, y + 10}}, {43, 74, 62, 255})
	}
	for i in 0 ..< 15 {
		a := k2.Vec2{map_rect.x + map_rect.w * 0.85 - f32(i) * 14, map_rect.y + f32(i) * 24}
		k2.draw_line(a, a + {-14, 24}, 13, {96, 143, 148, 255})
	}
	if show_routes {
		for i in 0 ..< len(POINTS) - 1 {
			a := k2.Vec2{map_rect.x, map_rect.y} + POINTS[i] * k2.Vec2{map_rect.w, map_rect.h}
			b := k2.Vec2{map_rect.x, map_rect.y} + POINTS[i + 1] * k2.Vec2{map_rect.w, map_rect.h}
			for j in 0 ..< 12 do k2.draw_circle(a + (b - a) * (f32(j) / 12), 2, {212, 191, 134, 255})
		}
	}
	for point, i in POINTS {
		pos := k2.Vec2{map_rect.x, map_rect.y} + point * k2.Vec2{map_rect.w, map_rect.h}
		hit := k2.Rect{pos.x - 18, pos.y - 18, 36, 36}
		if i == 3 do map_control = hit
		if !travelling && ui.is_mouse_in_rect(ctx, hit) && ctx.mouse_button == .Pressed do selected_place = i
		k2.draw_circle(pos, 16, {38, 59, 53, 255})
		k2.draw_circle(pos, 12, GOLD if i == selected_place else k2.Color{195, 198, 159, 255})
		k2.draw_circle(pos, 5, {91, 79, 54, 255})
		label({pos.x - 60, pos.y + 19, 155, 23}, PLACES[i], 12, CREAM)
		if i == selected_place && travelling {
			pulse := f32(math.sin(k2.get_time() * 4)) * 3
			ui.image_region(
				ctx,
				{pos.x - 12, pos.y - 49 + pulse, 24, 25},
				atlas,
				{171, 486, 22, 21},
			)
		}
	}
	label({map_rect.x + 10, map_rect.y + 8, 200, 24}, "NORTHERN REACH", 14, CREAM)
	label(
		{map_rect.x + 10, map_rect.y + map_rect.h - 25, 300, 20},
		"Select a gold waypoint to plan your journey",
		12,
		CREAM,
	)
}

draw_journal :: proc() {
	content := ui.begin_window(ctx, "QUEST JOURNAL", {932, 92, 324, 644}, {.Pinned})
	defer ui.end_window(ctx)
	label(row(&content, 28), fmt.tprintf("%d expeditions completed", completed), 17, CREAM)
	label(row(&content, 23), "The guild always has more work.", 14, CREAM)
	viewport := ui.panel(ctx, content, 10)
	defer ui.panel_end(ctx)
	journal_scroll.content_height = f32(len(QUESTS)) * 142
	list := ui.begin_scroll(ctx, viewport, &journal_scroll)
	for quest, i in QUESTS {
		card := ui.panel(ctx, row(&list, 132, 10), 10, skin({190, 100, 100, 100}))
		label(row(&card, 25), quest, 16)
		label(row(&card, 21), "Complete" if i < completed else "Guild commission", 13)
		label(row(&card, 20), "Explore a waypoint. Return safely.", 12)
		label(row(&card, 20), "Reward: 25 gold + a good story", 12)
		ui.separator(ctx, row(&card, 3, 0))
		ui.panel_end(ctx)
	}
	ui.end_scroll(ctx, viewport, &journal_scroll)
}

draw_settings :: proc() {
	content := ui.begin_window(ctx, "CAMP SETTINGS - drag to move", settings_rect, {.Resizable})
	ctx.current_window.min_size = {400, 300}
	settings_rect = ctx.current_window.rect
	defer ui.end_window(ctx)
	footer := ui.cut_bottom(&content, 42)
	ui.cut_bottom(&content, 10)
	viewport := ui.panel(ctx, content, 12)
	settings_scroll.content_height = 678
	list := ui.begin_scroll(ctx, viewport, &settings_scroll)
	label(row(&list, 28), "Make the road your own", 22)
	label(row(&list, 24), "Expedition paused while you are in camp.", 14)
	ui.separator(ctx, row(&list, 4))
	collect_control = row(&list, 38)
	ui.toggle(ctx, collect_control, "Collect expedition rewards", &auto_collect)
	ui.toggle(ctx, row(&list, 38), "Show map routes", &show_routes)
	speed_control = row(&list, 84)
	ui.slider(ctx, speed_control, "Journey speed", 0.5, 2, 0.25, &pace, "%.2fx")
	label(row(&list, 28), "TRAVEL STANCE", 16)
	modes := [?]string{"Cautious", "Balanced", "Bold"}
	ui.segmented(ctx, row(&list, 40), modes[:], &stance)
	label(row(&list, 28), "Bolder journeys are faster, but cost more HP.", 14)
	ui.separator(ctx, row(&list, 4))
	label(row(&list, 28), "FIELD GUIDE", 18)
	guide := [?]string {
		"Wheel or drag the thumb to scroll.",
		"Click the scrollbar track to jump.",
		"Drag this window by its title bar.",
		"Drag its lower-right corner to resize.",
		"Backpack and journal scroll independently.",
		"Camera zoom keeps text crisp at high DPI.",
	}
	for line in guide do label(row(&list, 25, 3), line, 14)
	ui.end_scroll(ctx, viewport, &settings_scroll)
	ui.panel_end(ctx)
	reset := ui.cut_left(&footer, 140)
	ui.cut_left(&footer, 8)
	saved_bg, saved_text := ctx.theme.widget_bg, ctx.theme.text
	ctx.theme.widget_bg, ctx.theme.text = k2.WHITE, CREAM
	reset_pressed := ui.button_label(ctx, reset, "Reset")
	ctx.theme.widget_bg, ctx.theme.text = saved_bg, saved_text
	if reset_pressed {
		auto_collect, show_routes = true, true
		pace = 1
		stance = 0
	}
	if button(footer, "Back to adventure") do settings_open = false
}

// Deterministic integration smoke: camera transforms, independent scroll views,
// modal input capture, toggles, map selection, travel, and window manipulation.
smoke_input :: proc(frame: int, camera: k2.Camera) {
	assert(ctx.slice_shader_ok)
	point := k2.Vec2{137, 241}
	roundtrip := k2.screen_to_camera(k2.camera_to_screen(point, camera), camera)
	assert(abs(roundtrip.x - point.x) < 0.01 && abs(roundtrip.y - point.y) < 0.01)
	clip := ui.clip_to_screen({20, 30, 100, 80}, camera)
	assert(abs(clip.w - 100 * camera.zoom) < 0.01 && abs(clip.h - 80 * camera.zoom) < 0.01)
	ctx.mouse_button = .Idle
	ctx.mouse_down = false
	ctx.mouse_pos = {-10000, -10000}
	ctx.scroll_delta = 0
	switch frame {
	case 1:
		ctx.mouse_pos = {1100, 280}; ctx.scroll_delta = -3
	case 2:
		ctx.mouse_pos = {160, 490}; ctx.scroll_delta = -3
	case 3:
		settings_open = true
	case 4:
		ctx.mouse_pos = {600, 380}; ctx.scroll_delta = -3
	case 5:
		// A modal blocks clicks on the expedition button.
		ctx.mouse_pos = {480, 650}; ctx.mouse_button = .Pressed
	case 6:
		settings_scroll.offset_y = 0
	case 7:
		ctx.mouse_pos = {650, 195}; ui.update_mouse_button(ctx, .Pressed)
	case 8:
		ctx.mouse_pos = {680, 215}; ctx.mouse_down = true
	case 9:
		ui.update_mouse_button(ctx, .Released)
	case 10:
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
		ctx.mouse_pos = {map_control.x + 18, map_control.y + 18}
		ui.update_mouse_button(ctx, .Pressed)
	case 15:
		ctx.animation = {}
		ctx.mouse_pos = {
			travel_control.x + 20,
			travel_control.y + 20,
		}; ui.update_mouse_button(ctx, .Pressed)
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
		assert(settings_rect.x > 410 && settings_rect.y > 180)
	case 11:
		assert(settings_rect.w > 460 && settings_rect.h > 430)
	case 14:
		assert(selected_place == 3)
	case 15:
		assert(travelling)
	case 17:
		assert(!auto_collect)
	case 20:
		assert(pace > 1)
	}
}
