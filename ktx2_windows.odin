#+build windows

package karl2d

import "base:runtime"

@(extra_linker_flags="/NODEFAULTLIB:libcmt")
foreign import karl2d_ktx2_native {
	"third_party/ktx2/windows-x64/karl2d_ktx2.lib",
	"system:msvcrt.lib",
	"system:vcruntime.lib",
	"system:ucrt.lib",
}

foreign karl2d_ktx2_native {
	karl2d_ktx2_transcode :: proc "c" (
		data: rawptr,
		data_size: u32,
		target: u32,
		output: rawptr,
		output_size: u32,
		width: ^u32,
		height: ^u32,
	) -> i32 ---
}

ktx2_transcode :: proc(
	bytes: []u8,
	width: int,
	height: int,
	allocator: runtime.Allocator,
) -> (Ktx2_Transcode_Result, bool) {
	block_count := ((width + 3) / 4) * ((height + 3) / 4)
	output := make([]u8, block_count * 16, allocator)
	if len(bytes) > int(max(u32)) || len(output) > int(max(u32)) {
		return {}, false
	}
	actual_width, actual_height: u32
	status := karl2d_ktx2_transcode(
		raw_data(bytes),
		u32(len(bytes)),
		6, // Basis Universal cTFBC7_RGBA
		raw_data(output),
		u32(len(output)),
		&actual_width,
		&actual_height,
	)
	if status != 0 || int(actual_width) != width || int(actual_height) != height {
		return {}, false
	}
	return {data = output, format = .BC7_RGBA}, true
}
