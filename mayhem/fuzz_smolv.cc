// Fuzzes the SMOL-V (compressed SPIR-V) decoder.
#include "smolv.h"

#include <stddef.h>
#include <stdint.h>

#include <vector>

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < 24) return -1;
    size_t outSize = smolv::GetDecodedBufferSize(data, size);
    if (outSize == 0 || outSize > (64u << 20)) return -1;
    std::vector<uint8_t> out(outSize);
    smolv::Decode(data, size, out.data(), outSize);
    return 0;
}
