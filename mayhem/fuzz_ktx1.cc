// Fuzzes the KTX1 container reader and its serializer round trip.
#include <image/Ktx1Bundle.h>

#include <utils/Panic.h>

#include <stddef.h>
#include <stdint.h>

#include <exception>
#include <vector>

using namespace image;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < 64) return -1;
    try {
        Ktx1Bundle bundle(data, (uint32_t) size);
        filament::math::float3 sh[9];
        bundle.getSphericalHarmonics(sh);
        size_t len = 0;
        bundle.getMetadata("sh", &len);
        bundle.getMetadata("KTXorientation", &len);
        for (uint32_t m = 0; m < bundle.getNumMipLevels(); m++) {
            for (uint32_t a = 0; a < bundle.getArrayLength(); a++) {
                for (uint32_t f = 0; f < (bundle.isCubemap() ? 6u : 1u); f++) {
                    uint8_t* blob; uint32_t blobSize;
                    bundle.getBlob({m, a, f}, &blob, &blobSize);
                    if (m >= 8) break;
                }
            }
        }
        uint32_t n = bundle.getSerializedLength();
        std::vector<uint8_t> out(n);
        bundle.serialize(out.data(), n);
    } catch (utils::Panic const&) {
    } catch (std::exception const&) {
    }
    return 0;
}
