package particle_system

import k2 "../.."
import "base:runtime"
import hm "core:container/handle_map"
import "core:log"
import "core:math"
import "core:math/rand"

Range :: struct {
	min, max: f32,
}

Color_Range :: struct {
	min, max: k2.Color,
}

Emitter_Handle :: distinct hm.Handle64
EMITTER_NONE :: Emitter_Handle{}

Emitter_Config :: struct {
	spawn_pos:              k2.Vec2,
	spawn_radius:           f32,
	emit_rate:              f32,
	angle_deg:              Range,
	speed_start, speed_end: Range,
	lifetime:               Range,
	size_start, size_end:   Range,
	color_start, color_end: Color_Range,
	rotation_start:         Range,
	rotation_speed:         Range,
	atlas:                  k2.Texture,
	source_rect:            k2.Rect,
	blend_mode:             k2.Blend_Mode,
	gravity:                k2.Vec2,
	max_particles:          u32,
}

Particle :: struct {
	pos:            k2.Vec2,
	vel:            k2.Vec2,
	life:           f32,
	size:           f32,
	rotation:       f32,
	color:          k2.Color,
	life_max:       f32,
	size_range:     Range,
	speed_range:    Range,
	rotation_speed: f32,
	color_range:    Color_Range,
}

Emitter :: struct {
	handle:           Emitter_Handle,
	config:           Emitter_Config,
	pool:             #soa[dynamic]Particle,
	emit_accumulator: f32,
	active:           b32,
	offset:           k2.Vec2,
}

Particle_System :: struct {
	emitters:  hm.Dynamic_Handle_Map(Emitter, Emitter_Handle),
	allocator: runtime.Allocator,

	// Karl2D's internal state, returned by `k2.init`. The renderer reaches into it to write sprite
	// vertices directly into the batch buffer. See the "Fast sprite batch" section below.
	state:     ^k2.State,
}

// -------- Particle system management ----------
particle_system_create :: proc(
	state: ^k2.State,
	allocator := context.allocator,
) -> ^Particle_System {
	system, err := new(Particle_System, allocator)
	log.assertf(err == nil, "Failed allocating memory for particle system: %v", err)
	system.allocator = allocator
	system.state = state
	hm.dynamic_init(&system.emitters, allocator)
	return system
}

particle_system_destroy :: proc(system: ^Particle_System) {
	if system == nil do return
	for iter := hm.dynamic_iterator_make(
		&system.emitters,
	); emitter, _ in hm.dynamic_iterate(&iter) {
		delete(emitter.pool)
	}
	hm.dynamic_destroy(&system.emitters)
	free(system, system.allocator)
}

particle_system_update :: proc(system: ^Particle_System, dt: f32) {
	for iter := hm.dynamic_iterator_make(
		&system.emitters,
	); emitter, _ in hm.dynamic_iterate(&iter) {
		emitter_emit(emitter, dt)
		emitter_update(emitter, dt)
	}
}

particle_system_render :: proc(system: ^Particle_System) {
	// Group by blend mode to preserve batching. Only change state for nonempty passes.
	for mode in ([3]k2.Blend_Mode{.Alpha, .Premultiplied_Alpha, .Additive}) {
		mode_set := false
		for iter := hm.dynamic_iterator_make(
			&system.emitters,
		); emitter, _ in hm.dynamic_iterate(&iter) {
			if emitter.config.blend_mode == mode && len(emitter.pool) > 0 {
				if !mode_set {
					k2.set_blend_mode(mode)
					mode_set = true
				}
				emitter_render_batch(system.state, emitter^)
			}
		}
	}
	k2.set_blend_mode(nil)
}

particle_system_get_particle_count :: proc(system: ^Particle_System) -> i32 {
	total: i32 = 0
	for iter := hm.dynamic_iterator_make(
		&system.emitters,
	); emitter, _ in hm.dynamic_iterate(&iter) {
		total += cast(i32)len(emitter.pool)
	}
	return total
}

// -------- Emitter management ----------
particle_system_add_emitter :: proc(
	system: ^Particle_System,
	config: Emitter_Config,
) -> Emitter_Handle {
	emitter := Emitter {
		config = config,
		pool   = make(#soa[dynamic]Particle, 0, config.max_particles, system.allocator),
	}
	handle, err := hm.add(&system.emitters, emitter)
	log.assertf(err == nil, "Failed adding emitter: %v", err)
	return handle
}

particle_system_remove_emitter :: proc(system: ^Particle_System, handle: Emitter_Handle) {
	if emitter := hm.get(&system.emitters, handle); emitter != nil {
		delete(emitter.pool)
	}
	hm.remove(&system.emitters, handle)
}

emitter_set_position :: proc(system: ^Particle_System, handle: Emitter_Handle, pos: k2.Vec2) {
	if emitter := hm.get(&system.emitters, handle); emitter != nil {
		emitter.offset = pos
	}
}

emitter_start :: proc(system: ^Particle_System, handle: Emitter_Handle) {
	if emitter := hm.get(&system.emitters, handle); emitter != nil {
		emitter.active = true
	}
}

emitter_stop :: proc(system: ^Particle_System, handle: Emitter_Handle) {
	if emitter := hm.get(&system.emitters, handle); emitter != nil {
		emitter.active = false
	}
}

emitter_is_active :: proc(system: ^Particle_System, handle: Emitter_Handle) -> bool {
	emitter := hm.get(&system.emitters, handle)
	return emitter != nil && bool(emitter.active)
}

emitter_burst :: proc(system: ^Particle_System, handle: Emitter_Handle, count: i32) {
	emitter := hm.get(&system.emitters, handle)
	if emitter == nil do return
	if len(emitter.pool) + cast(int)count > cap(emitter.pool) do return
	emitter_spawn(emitter, count)
}

// -------- Emitters ----------
@(private = "file")
emitter_render_batch :: proc(state: ^k2.State, emitter: Emitter) {
	// Submit the whole emitter as one sprite batch. This hoists all per-sheet work (UV/flip/texture
	// setup) out of the per-particle path, and the particles stream straight into the vertex buffer
	// with no intermediate array. We index the SoA fields we need directly instead of
	// `for particle in emitter.pool`, which would gather every field of the struct (vel, life, the
	// ranges, ...) per particle.
	batch := sprite_batch_begin(state, emitter.config.atlas, emitter.config.source_rect)
	#no_bounds_check for i in 0 ..< len(emitter.pool) {
		size := emitter.pool.size[i]
		pos := emitter.pool.pos[i]
		sprite_batch_add(
			&batch,
			{pos.x, pos.y, size, size},
			origin = {size / 2, size / 2},
			rotation = emitter.pool.rotation[i],
			tint = emitter.pool.color[i],
		)
	}
	sprite_batch_end(&batch)
}

@(private = "file")
emitter_emit :: proc(emitter: ^Emitter, dt: f32) {
	if !emitter.active do return

	emitter.emit_accumulator += emitter.config.emit_rate * dt
	count := min(i32(emitter.emit_accumulator), i32(cap(emitter.pool) - len(emitter.pool)))
	emitter_spawn(emitter, count)
	emitter.emit_accumulator -= f32(count)
	emitter.emit_accumulator = min(emitter.emit_accumulator, emitter.config.emit_rate)
}

@(private = "file")
emitter_spawn :: proc(emitter: ^Emitter, count: i32) {
	for _ in 0 ..< count {
		particle: Particle
		angle := rand.float32_range(0, 2 * math.PI)
		radius := rand.float32_range(0, emitter.config.spawn_radius)
		projected := k2.Vec2{math.cos(angle) * radius, math.sin(angle) * radius}
		particle.pos = emitter.offset + emitter.config.spawn_pos + projected

		emit_angle := math.to_radians(sample_random_range(emitter.config.angle_deg))
		speed := sample_random_range(emitter.config.speed_start)
		particle.vel = k2.Vec2{math.cos(emit_angle) * speed, math.sin(emit_angle) * speed}

		particle.speed_range = Range{speed, sample_random_range(emitter.config.speed_end)}

		life := sample_random_range(emitter.config.lifetime)
		particle.life = life
		particle.life_max = life

		particle.size_range = Range {
			sample_random_range(emitter.config.size_start),
			sample_random_range(emitter.config.size_end),
		}
		particle.size = particle.size_range.min

		particle.color_range = Color_Range {
			sample_random_color_range(emitter.config.color_start),
			sample_random_color_range(emitter.config.color_end),
		}
		particle.color = particle.color_range.min

		particle.rotation = sample_random_range(emitter.config.rotation_start)
		particle.rotation_speed = sample_random_range(emitter.config.rotation_speed)

		append_soa(&emitter.pool, particle)
	}
}

@(private = "file")
emitter_update :: proc(emitter: ^Emitter, dt: f32) {
	gravity := emitter.config.gravity

	i := 0
	for i < len(emitter.pool) {
		emitter.pool.life[i] -= dt
		if emitter.pool.life[i] <= 0 {
			unordered_remove_soa(&emitter.pool, i)
			continue
		}

		emitter.pool.vel[i] += gravity * dt
		emitter.pool.pos[i] += emitter.pool.vel[i] * dt
		emitter.pool.rotation[i] += emitter.pool.rotation_speed[i] * dt

		t := 1.0 - (emitter.pool.life[i] / emitter.pool.life_max[i])

		emitter.pool.size[i] =
			emitter.pool.size_range[i].min +
			(emitter.pool.size_range[i].max - emitter.pool.size_range[i].min) * t
		emitter.pool.color[i] = color_lerp(
			emitter.pool.color_range[i].min,
			emitter.pool.color_range[i].max,
			t,
		)

		// TODO: Get rid of this along the speed_end params and just let gravity do its thing?
		current_speed :=
			emitter.pool.speed_range[i].min +
			(emitter.pool.speed_range[i].max - emitter.pool.speed_range[i].min) * t
		v := emitter.pool.vel[i]
		v_mag := math.sqrt(v.x * v.x + v.y * v.y)
		if v_mag > 0.0001 do emitter.pool.vel[i] = v * (current_speed / v_mag)

		i += 1
	}
}

// -------- Utils ----------
@(private = "file")
sample_random_range :: proc(range: Range) -> f32 {
	return range.min + rand.float32() * (range.max - range.min)
}

@(private = "file")
sample_random_u8_range :: proc(min: u8, max: u8) -> u8 {
	return min + cast(u8)(rand.int31() % (i32(max) - i32(min) + 1))
}

@(private = "file")
sample_random_color_range :: proc(color_range: Color_Range) -> k2.Color {
	return {
		sample_random_u8_range(color_range.min.r, color_range.max.r),
		sample_random_u8_range(color_range.min.g, color_range.max.g),
		sample_random_u8_range(color_range.min.b, color_range.max.b),
		sample_random_u8_range(color_range.min.a, color_range.max.a),
	}
}

@(private = "file")
color_lerp :: proc(initial: k2.Color, target: k2.Color, t: f32) -> k2.Color {
	return {
		u8(f32(initial.r) + (f32(target.r) - f32(initial.r)) * t),
		u8(f32(initial.g) + (f32(target.g) - f32(initial.g)) * t),
		u8(f32(initial.b) + (f32(target.b) - f32(initial.b)) * t),
		u8(f32(initial.a) + (f32(target.a) - f32(initial.a)) * t),
	}
}

// -------- Fast sprite batch ----------
//
// A minimal sprite batcher that writes vertices straight into Karl2D internal vertex buffer,
// skipping the per-vertex overhead of the public `k2.draw_*` API. It reaches into `k2.State`
// directly, which is why it lives here in the example rather than in the library.
//
// It only handles the case the particle atlas guarantees: the default shader is bound (the vertex is
// exactly position + uv + color, with no input overrides) and the texture is not a render texture
// (so it needs no vertical flip). Don't copy this into code that can't make those guarantees, use
// `k2.draw_texture_fit` there instead.
@(private = "file")
Sprite_Batch :: struct {
	state:        ^k2.State,
	texture:      k2.Texture_Handle,
	uvs:          [6]k2.Vec2,
	pos_offset:   int,
	uv_offset:    int,
	color_offset: int,
	vertex_size:  int,
}

@(private = "file")
sprite_batch_begin :: proc(
	state: ^k2.State,
	texture: k2.Texture,
	source: k2.Rect,
) -> Sprite_Batch {
	ts := k2.Vec2{f32(texture.width), f32(texture.height)}
	up := k2.Vec2{source.x, source.y} / ts
	us := k2.Vec2{source.w, source.h} / ts

	shd := state.current_shader

	batch: Sprite_Batch
	batch.state = state
	batch.texture = texture.handle
	batch.uvs = {up, up + {us.x, 0}, up + us, up, up + us, up + {0, us.y}}
	batch.pos_offset = shd.default_input_offsets[.Position]
	batch.uv_offset = shd.default_input_offsets[.UV]
	batch.color_offset = shd.default_input_offsets[.Color]
	batch.vertex_size = shd.vertex_size
	return batch
}

@(private = "file")
sprite_batch_add :: proc(
	batch: ^Sprite_Batch,
	dest: k2.Rect,
	origin: k2.Vec2,
	rotation: f32,
	tint: k2.Color,
) {
	state := batch.state
	vsz := batch.vertex_size

	// Register these vertices with the draw call and flush if the buffer is full.
	k2._prepare_draw(batch.texture, 6)

	tl, tr, bl, br: k2.Vec2

	// Rotation adapted from Raylib's "DrawTexturePro"
	if rotation == 0 {
		x := dest.x - origin.x
		y := dest.y - origin.y
		tl = {x, y}
		tr = {x + dest.w, y}
		bl = {x, y + dest.h}
		br = {x + dest.w, y + dest.h}
	} else {
		sin_rot := math.sin(rotation)
		cos_rot := math.cos(rotation)
		x := dest.x
		y := dest.y
		dx := -origin.x
		dy := -origin.y

		tl = {x + dx * cos_rot - dy * sin_rot, y + dx * sin_rot + dy * cos_rot}

		tr = {
			x + (dx + dest.w) * cos_rot - dy * sin_rot,
			y + (dx + dest.w) * sin_rot + dy * cos_rot,
		}

		bl = {
			x + dx * cos_rot - (dy + dest.h) * sin_rot,
			y + dx * sin_rot + (dy + dest.h) * cos_rot,
		}

		br = {
			x + (dx + dest.w) * cos_rot - (dy + dest.h) * sin_rot,
			y + (dx + dest.w) * sin_rot + (dy + dest.h) * cos_rot,
		}
	}

	positions := [6]k2.Vec2{tl, tr, br, tl, br, bl}

	buf := state.vertex_buffer_cpu
	base := state.vertex_buffer_cpu_used

	// `base + vsz * 6` is guaranteed to fit by `_prepare_draw`, and every offset stays within a
	// vertex, so these writes are in bounds by construction.
	#no_bounds_check for v in 0 ..< 6 {
		o := base + v * vsz
		(^k2.Vec2)(&buf[o + batch.pos_offset])^ = positions[v]
		(^k2.Vec2)(&buf[o + batch.uv_offset])^ = batch.uvs[v]
		(^k2.Color)(&buf[o + batch.color_offset])^ = tint
	}

	state.vertex_buffer_cpu_used = base + vsz * 6
}

@(private = "file")
sprite_batch_end :: proc(batch: ^Sprite_Batch) {
	// The vertices are already in Karl2D's batch buffer and flush like any other batched drawing
	// (when the buffer fills up or `k2.present` is called), so there's nothing
	// to do here. Kept for symmetry with `sprite_batch_begin`.
}
