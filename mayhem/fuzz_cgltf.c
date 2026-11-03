/* Fuzzes the vendored cgltf glTF/GLB parser and validator (shipped with filament; same entry point
   as third_party/cgltf/fuzz/main.c). */
#define CGLTF_IMPLEMENTATION
#include "../third_party/cgltf/cgltf.h"

int LLVMFuzzerTestOneInput(const uint8_t *Data, size_t Size)
{
    if (Size < 4) return -1;
    cgltf_options options = {cgltf_file_type_invalid};
    cgltf_data* data = NULL;
    cgltf_result res = cgltf_parse(&options, Data, Size, &data);
    if (res == cgltf_result_success)
    {
        cgltf_validate(data);
        cgltf_free(data);
    }
    return 0;
}
