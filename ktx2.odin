package karl2d

import "log"

KTX2_IDENTIFIER := [12]u8{0xAB, 0x4B, 0x54, 0x58, 0x20, 0x32, 0x30, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A}

ktx2_is_data :: proc(bytes: []u8) -> bool {
	if len(bytes) < len(KTX2_IDENTIFIER) {
		return false
	}
	for value, index in KTX2_IDENTIFIER {
		if bytes[index] != value {
			return false
		}
	}
	return true
}

ktx2_u32 :: proc(bytes: []u8, offset: int) -> u32 {
	return u32(bytes[offset]) |
		u32(bytes[offset + 1]) << 8 |
		u32(bytes[offset + 2]) << 16 |
		u32(bytes[offset + 3]) << 24
}

ktx2_dimensions :: proc(bytes: []u8) -> (width, height: int, ok: bool) {
	if len(bytes) < 80 || !ktx2_is_data(bytes) {
		return
	}
	// Karl2D currently accepts one 2D UASTC/Zstd image without mipmaps or arrays.
	if ktx2_u32(bytes, 12) != 0 ||
		ktx2_u32(bytes, 28) != 0 ||
		ktx2_u32(bytes, 32) != 0 ||
		ktx2_u32(bytes, 36) != 1 ||
		ktx2_u32(bytes, 40) != 1 ||
		ktx2_u32(bytes, 44) != 2 {
		return
	}
	w := ktx2_u32(bytes, 20)
	h := ktx2_u32(bytes, 24)
	if w == 0 || h == 0 || w % 4 != 0 || h % 4 != 0 {
		return
	}
	return int(w), int(h), true
}

Ktx2_Transcode_Result :: struct {
	data: []u8,
	format: Compressed_Texture_Format,
	uncompressed: bool,
}

// Load a UASTC KTX2 image, transcode it directly to a GPU-native block format, and upload it.
ktx2_load_texture :: proc(bytes: []u8, options: Load_Texture_Options = {}) -> Texture {
	if .Premultiply_Alpha in options {
		log.error("KTX2 textures cannot be premultiplied at load time; encode premultiplied source pixels instead")
		return {}
	}
	width, height, dimensions_ok := ktx2_dimensions(bytes)
	if !dimensions_ok {
		log.error("Unsupported or invalid KTX2 texture; expected one block-aligned UASTC/Zstd 2D image")
		return {}
	}
	result, transcode_ok := ktx2_transcode(bytes, width, height, frame_allocator)
	if !transcode_ok {
		log.error("Failed transcoding KTX2 texture")
		return {}
	}

	if result.uncompressed {
		return load_texture_from_bytes_raw(result.data, width, height, .RGBA_8_Norm)
	}
	return load_texture_from_bytes_compressed(result.data, width, height, result.format)
}
