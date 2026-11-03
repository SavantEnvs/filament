// Fuzzes the uberz archive reader (in-place offset -> pointer fixup of a mapped archive blob).
#include <uberz/ReadableArchive.h>

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

using namespace filament::uberz;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < sizeof(ReadableArchive)) return -1;
    // Archives are word-aligned blobs.
    size_t padded = (size + 7) & ~size_t(7);
    void* mem = aligned_alloc(8, padded);
    memcpy(mem, data, size);
    convertOffsetsToPointers(reinterpret_cast<ReadableArchive*>(mem), size);
    free(mem);
    return 0;
}
