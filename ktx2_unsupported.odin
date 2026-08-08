#+build !windows
#+build !js

package karl2d

import "base:runtime"

ktx2_transcode :: proc(
	bytes: []u8,
	width: int,
	height: int,
	allocator: runtime.Allocator,
) -> (Ktx2_Transcode_Result, bool) {
	return {}, false
}
