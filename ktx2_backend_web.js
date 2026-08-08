let karl2dKtx2Module = null;
let karl2dKtx2WasmMemory = null;
let karl2dKtx2Gl = null;

async function initializeKarl2dKtx2(canvas) {
	karl2dKtx2Gl = canvas.getContext("webgl2");
	if (!karl2dKtx2Gl) {
		throw new Error("Karl2D KTX2 loading requires WebGL 2");
	}
	karl2dKtx2Module = await createKtxReadModule({
		preinitializedWebGLContext: karl2dKtx2Gl,
		locateFile: (name) => name === "libktx_read.wasm" ? "libktx_read.wasm" : name,
	});
}

function setKarl2dKtx2WasmMemory(memory) {
	karl2dKtx2WasmMemory = memory;
}

function preferredKarl2dKtx2Format() {
	const gl = karl2dKtx2Gl;
	gl.getExtension("WEBGL_compressed_texture_astc");
	gl.getExtension("EXT_texture_compression_bptc");
	gl.getExtension("WEBGL_compressed_texture_s3tc");
	const supported = Array.from(gl.getParameter(gl.COMPRESSED_TEXTURE_FORMATS));
	if (supported.includes(0x93B0)) return 10; // ASTC 4x4 RGBA
	if (supported.includes(0x8E8C)) return 6;  // BC7 RGBA
	if (supported.includes(0x9278)) return 1;  // ETC2 RGBA8
	if (supported.includes(0x83F3)) return 3;  // BC3 RGBA
	return 13; // RGBA32 fallback
}

const karl2dKtx2JsImports = {
	karl2d_ktx2_js: {
		preferred_format: preferredKarl2dKtx2Format,
		transcode: function(inputPtr, inputLength, target, outputPtr, outputLength) {
			if (!karl2dKtx2Module || !karl2dKtx2WasmMemory) return 1;
			const source = new Uint8Array(karl2dKtx2WasmMemory.buffer, inputPtr, inputLength);
			let texture = null;
			try {
				texture = new karl2dKtx2Module.ktxTexture(source);
				const targets = karl2dKtx2Module.TranscodeTarget;
				const targetFormat = {
					1: targets.ETC2_RGBA,
					3: targets.BC3_RGBA,
					6: targets.BC7_RGBA,
					10: targets.ASTC_4x4_RGBA,
					13: targets.RGBA32,
				}[target];
				if (targetFormat === undefined) return 2;
				if (texture.transcodeBasis(targetFormat, 0) !== karl2dKtx2Module.ErrorCode.SUCCESS) {
					return 3;
				}
				const image = texture.getImage(0, 0, 0);
				if (!image || image.byteLength !== outputLength) return 4;
				new Uint8Array(karl2dKtx2WasmMemory.buffer, outputPtr, outputLength).set(image);
				return 0;
			} catch (error) {
				console.error("KTX2 transcode failed", error);
				return 5;
			} finally {
				if (texture) texture.delete();
			}
		},
	},
};

window.initializeKarl2dKtx2 = initializeKarl2dKtx2;
window.setKarl2dKtx2WasmMemory = setKarl2dKtx2WasmMemory;
