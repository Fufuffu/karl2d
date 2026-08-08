#include <cstdint>

#include "basisu_transcoder.h"

extern "C" int karl2d_ktx2_transcode(
    const void* data,
    std::uint32_t data_size,
    std::uint32_t target,
    void* output,
    std::uint32_t output_size,
    std::uint32_t* width,
    std::uint32_t* height) {
    if (!data || !output || !width || !height) {
        return 1;
    }

    static const bool initialized = [] {
        basist::basisu_transcoder_init();
        return true;
    }();
    (void)initialized;

    basist::ktx2_transcoder transcoder;
    if (!transcoder.init(data, data_size) || transcoder.get_levels() != 1 ||
        transcoder.get_faces() != 1 || transcoder.get_layers() > 1) {
        return 2;
    }

    *width = transcoder.get_width();
    *height = transcoder.get_height();
    if (!transcoder.start_transcoding()) {
        return 3;
    }

    const auto format = static_cast<basist::transcoder_texture_format>(target);
    const bool rgba32 = format == basist::transcoder_texture_format::cTFRGBA32;
    const std::uint64_t units = rgba32
        ? static_cast<std::uint64_t>(*width) * *height
        : static_cast<std::uint64_t>((*width + 3) / 4) * ((*height + 3) / 4);
    const std::uint64_t required_size = units * (rgba32 ? 4 : 16);
    if (units > UINT32_MAX || required_size > output_size) {
        return 4;
    }

    return transcoder.transcode_image_level(
        0,
        0,
        0,
        output,
        static_cast<std::uint32_t>(units),
        format) ? 0 : 5;
}
