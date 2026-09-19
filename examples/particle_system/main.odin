package particle_system

import k2 "../.."
import "core:fmt"
import "core:math"

SCREEN_WIDTH :: 1000
SCREEN_HEIGHT :: 750

ps: ^Particle_System
atlas: k2.Texture
fire: Emitter_Handle
smoke: Emitter_Handle
water_streams: [5]Emitter_Handle

main :: proc() {
	init()
	for step() {}
	shutdown()
}

init_fire_smoke :: proc() {
	smoke_cfg := Emitter_Config {
		spawn_pos      = {0, -10},
		spawn_radius   = 20,
		emit_rate      = 200,
		angle_deg      = {-100, -80},
		speed_start    = {30, 60},
		speed_end      = {10, 20},
		lifetime       = {2, 10},
		size_start     = {40, 60},
		size_end       = {80, 120},
		color_start    = {{80, 80, 80, 130}, {120, 120, 120, 170}},
		color_end      = {{50, 50, 50, 0}, {80, 80, 80, 0}},
		rotation_start = {0, 2 * math.PI},
		rotation_speed = {-math.PI / 36, math.PI / 36},
		atlas          = atlas,
		source_rect    = {512, 0, 512, 512},
		blend_mode     = .Alpha,
		max_particles  = 10000,
	}

	smoke = particle_system_add_emitter(ps, smoke_cfg)
	emitter_set_position(ps, smoke, {SCREEN_WIDTH / 2.0, SCREEN_HEIGHT / 2.0})
	emitter_start(ps, smoke)

	fire_cfg := Emitter_Config {
		spawn_pos      = {0, 0},
		spawn_radius   = 10,
		emit_rate      = 50000,
		angle_deg      = {-110, -70},
		speed_start    = {100, 200},
		speed_end      = {20, 50},
		lifetime       = {0.5, 1.5},
		size_start     = {15, 25},
		size_end       = {2, 5},
		color_start    = {{255, 150, 0, 8}, {255, 220, 50, 16}},
		color_end      = {{255, 0, 0, 0}, {255, 50, 0, 2}},
		rotation_start = {0, 2 * math.PI},
		rotation_speed = {-math.PI / 2, math.PI / 2},
		atlas          = atlas,
		source_rect    = {0, 0, 512, 512},
		blend_mode     = .Additive,
		max_particles  = 100000,
	}

	fire = particle_system_add_emitter(ps, fire_cfg)
	emitter_set_position(ps, fire, {SCREEN_WIDTH / 2.0, SCREEN_HEIGHT / 2.0})
	emitter_start(ps, fire)
}

init_water_sprinkler :: proc() {
	sprinkler_pos := k2.Vec2{SCREEN_WIDTH / 2.0, SCREEN_HEIGHT - 100}
	stream_angles := [5]f32{-110, -100, -90, -80, -70}

	for i in 0 ..< 5 {
		water_cfg := Emitter_Config {
			spawn_pos      = {0, 0},
			spawn_radius   = 3,
			emit_rate      = 18000,
			angle_deg      = {stream_angles[i] - 3, stream_angles[i] + 3},
			speed_start    = {300, 400},
			speed_end      = {150, 250},
			lifetime       = {1.5, 2.5},
			size_start     = {4, 8},
			size_end       = {2, 4},
			color_start    = {{100, 180, 230, 200}, {150, 220, 255, 255}},
			color_end      = {{80, 200, 255, 50}, {120, 240, 255, 100}},
			rotation_start = {0, 0},
			rotation_speed = {0, 0},
			atlas          = atlas,
			source_rect    = {0, 0, 512, 512},
			blend_mode     = .Alpha,
			gravity        = {0, 400},
			max_particles  = 90000,
		}

		water_streams[i] = particle_system_add_emitter(ps, water_cfg)
		emitter_set_position(ps, water_streams[i], sprinkler_pos)
		emitter_start(ps, water_streams[i])
	}
}

init :: proc() {
	state := k2.init(
		SCREEN_WIDTH,
		SCREEN_HEIGHT,
		"Particles",
		options = {window_mode = .Windowed_Resizable},
	)
	atlas = k2.load_texture_from_bytes(#load("atlas.png"))
	ps = particle_system_create(state)
	init_fire_smoke()
	init_water_sprinkler()
}

step :: proc() -> bool {
	if !k2.update() {
		return false
	}

	dt := k2.get_frame_time()
	mouse := k2.get_mouse_position()

	emitter_set_position(ps, fire, mouse)
	emitter_set_position(ps, smoke, mouse)

	if k2.mouse_button_went_down(.Left) {
		emitter_burst(ps, fire, 200)
	}

	if k2.key_went_down(.Space) {
		if emitter_is_active(ps, fire) {
			emitter_stop(ps, fire)
			emitter_stop(ps, smoke)
		} else {
			emitter_start(ps, fire)
			emitter_start(ps, smoke)
		}
	}

	particle_system_update(ps, dt)

	k2.clear(k2.BLACK)

	particle_system_render(ps)

	k2.draw_text(fmt.tprintf("FPS: %v", int(1.0 / dt)), {10, 10}, 20, k2.WHITE)
	k2.draw_text(
		fmt.tprintf("Particles: %v", particle_system_get_particle_count(ps)),
		{10, 35},
		20,
		k2.WHITE,
	)
	k2.draw_text("Move mouse to control fire", {10, 60}, 16, k2.GRAY)
	k2.draw_text("Click for burst, Space to toggle", {10, 80}, 16, k2.GRAY)

	k2.present()

	free_all(context.temp_allocator)
	return true
}

shutdown :: proc() {
	particle_system_destroy(ps)
	k2.destroy_texture(atlas)
	k2.shutdown()
}
