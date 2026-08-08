#+build js

package karl2d

import "base:runtime"

foreign import karl2d_ktx2_js "karl2d_ktx2_js"

@(default_calling_convention="contextless")
foreign karl2d_ktx2_js {
	@(link_name="preferred_format")
	ktx2_js_preferred_format :: proc() -> i32 ---
	@(link_name="transcode")
	ktx2_js_transcode :: proc(bytes: []u8, target: i32, output: []u8) -> i32 ---
}

ktx2_transcode :: proc(
	bytes: []u8,
	width: int,
	height: int,
	allocator: runtime.Allocator,
) -> (Ktx2_Transcode_Result, bool) {
	target := ktx2_js_preferred_format()
	result := Ktx2_Transcode_Result{}
	output_size: int
	switch target {
	case 1:
		result.format = .ETC2_RGBA
	case 3:
		result.format = .BC3_RGBA
	case 6:
		result.format = .BC7_RGBA
	case 10:
		result.format = .ASTC_4x4_RGBA
	case 13:
		result.uncompressed = true
	case:
		return {}, false
	}
	if result.uncompressed {
		output_size = width * height * 4
	} else {
		output_size = ((width + 3) / 4) * ((height + 3) / 4) * 16
	}
	result.data = make([]u8, output_size, allocator)
	if ktx2_js_transcode(bytes, target, result.data) != 0 {
		return {}, false
	}
	return result, true
}
