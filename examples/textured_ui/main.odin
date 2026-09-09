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
	{"Wayfarer's blade", "+8 attack / equipped", ATLAS_BLADE, 1},
	{"Ember potion", "Restores 25 health", ATLAS_ORANGE_LEFT, 2},
	{"Moonwater", "Restores 30 mana", ATLAS_BLUE_LEFT, 2},
	{"Old brass key", "Opens the watchtower", ATLAS_KEY, 3},
	{"Leather gloves", "+2 defense", ATLAS_LEATHER_GLOVES, 1},
	{"Silver gauntlet", "+5 defense", ATLAS_SILVER_GAUNTLET, 1},
	{"Forest tonic", "Restores 25 health", ATLAS_GREEN_POTION, 2},
	{"Guild seal", "Proof of membership", ATLAS_SEAL, 3},
	{"Ranger's knife", "+4 attack", ATLAS_KNIFE, 1},
	{"Lucky coin", "A little extra luck", ATLAS_COIN, 3},
	{"Travel gloves", "Warm and well worn", ATLAS_TRAVEL_GLOVES, 1},
	{"Sun elixir", "Restores 25 health", ATLAS_YELLOW_POTION, 2},
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

frames: int

main :: proc() {
	init()
	defer shutdown()
	for step() {}
}

init :: proc() {
	k2.init(
		#config(UI_WIDTH, 1280),
		#config(UI_HEIGHT, 800),
		"Hearth & Hollow | camera UI playground",
		options = {window_mode = .Windowed_Resizable},
	)
	ctx = ui.init(6, 8)
	atlas = k2.load_texture_from_bytes(#load("assets/uipack_rpg_sheet.png"))
	portrait = k2.load_texture_from_bytes(#load("assets/portrait.png"))
	init_theme()
	frames = 0
}

step :: proc() -> bool {
	if !k2.update() do return false
	size := k2.get_screen_size()
	if size.x <= 0 || size.y <= 0 do return true
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
	when #config(UI_SMOKE_TEST, false) do smoke_input(frames)
	ui.begin_frame(ctx, dt)
	k2.clear({31, 48, 51, 255})
	// Block game input while the modal is open.
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
		if frames == 23 do return false
	}
	return true
}

shutdown :: proc() {
	ui.destroy(ctx)
	k2.destroy_texture(portrait)
	k2.destroy_texture(atlas)
	k2.shutdown()
	when #config(UI_SMOKE_TEST, false) {
		assert(frames == 23)
		fmt.println(
			"PASS: 23 frames; camera, scrolling, modal, drag, resize, map, expedition, toggle and slider checks",
		)
	}
}

draw_game :: proc() {
	// The HUD uses the scene background.
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
	when #config(UI_SMOKE_TEST, false) do backpack_viewport = viewport
	list := ui.begin_scroll(ctx, viewport, &backpack_scroll)
	for item, i in ITEMS {
		if category != 0 && item.category != category do continue
		item_rect := row(&list, 56, 6)
		if ui.is_mouse_in_rect(ctx, item_rect) && ctx.mouse_button == .Pressed do selected_item = i
		if selected_item == i do ui.draw_skin(ctx, item_rect, skin(ATLAS_CARD))
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
				ATLAS_WAYPOINT,
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
	when #config(UI_SMOKE_TEST, false) do journal_viewport = viewport
	list := ui.begin_scroll(ctx, viewport, &journal_scroll)
	for quest, i in QUESTS {
		card := ui.panel(ctx, row(&list, 132, 10), 10, skin(ATLAS_CARD))
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
	when #config(UI_SMOKE_TEST, false) do settings_viewport = viewport
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
