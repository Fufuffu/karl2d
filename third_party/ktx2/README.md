# Karl2D KTX2 dependencies

Karl2D uses a small C ABI around the Basis Universal v2.1 transcoder on native Windows and
KTX-Software 4.4.2's read-only WebAssembly binding in web builds. Both consume the same UASTC KTX2
payloads with Zstandard supercompression.

Pinned upstream sources:

- Basis Universal v2.1: <https://github.com/BinomialLLC/basis_universal/tree/v2_1_0>
- KTX-Software 4.4.2: <https://github.com/KhronosGroup/KTX-Software/releases/tag/v4.4.2>

The native library was built for Windows x64 with MSVC from `native/karl2d_ktx2.cpp`, upstream
`transcoder/basisu_transcoder.cpp`, and upstream `zstd/zstddeclib.c`, with C++17, optimization, the
dynamic MSVC runtime (`/MD`), and `BASISD_SUPPORT_KTX2_ZSTD=1`. The Web files are unmodified release artifacts from
`KTX-Software-4.4.2-Web-libktx_read.zip`.

SHA-256:

- `windows-x64/karl2d_ktx2.lib`: `36288953903FF4A3D0E3E8FE9EBD8C04B64BA7619B8F6817E6705FD3B02E1C03`
- `web/libktx_read.js`: `235D8265B5C30908272ECD3A33502A6B9175F5518C671B753B0F0FCAAF48FCA8`
- `web/libktx_read.wasm`: `8336A23659F306C93F45816022DCDFAE122F66EAF566488A2B7CF40E0BF65F0E`

License and attribution texts are retained alongside the artifacts.
