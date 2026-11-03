// Fuzzes imageio's format sniffing and PNG / Radiance HDR / PSD / OpenEXR decoders.
#include <imageio/ImageDecoder.h>

#include <stddef.h>
#include <stdint.h>

#include <exception>
#include <sstream>
#include <string>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < 16) return -1;
    std::istringstream stream(std::string(reinterpret_cast<const char*>(data), size));
    try {
        image::ImageDecoder::decode(stream, "fuzz", image::ImageDecoder::ColorSpace::SRGB);
    } catch (std::exception const&) {
    }
    return 0;
}
