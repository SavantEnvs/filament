// Fuzzes filament's runtime parser for compiled material packages (.filamat): the chunk
// container, dictionary, uniform/sampler/descriptor blocks and the shader table.
#include "MaterialParser.h"

#include <private/filament/BufferInterfaceBlock.h>
#include <private/filament/ConstantInfo.h>
#include <private/filament/PushConstantInfo.h>
#include <private/filament/SamplerInterfaceBlock.h>
#include <private/filament/SubpassInfo.h>

#include <utils/CString.h>
#include <utils/FixedCapacityVector.h>

#include <stddef.h>
#include <stdint.h>

#include <vector>

using namespace filament;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size < 16) return -1;
    // The parser keeps pointers into the buffer; give it an exactly-sized heap copy.
    std::vector<uint8_t> copy(data, data + size);

    MaterialParser parser(utils::FixedCapacityVector<backend::ShaderLanguage>{
            backend::ShaderLanguage::ESSL3, backend::ShaderLanguage::ESSL1,
            backend::ShaderLanguage::SPIRV, backend::ShaderLanguage::MSL,
            backend::ShaderLanguage::WGSL},
            copy.data(), copy.size());
    if (parser.parse() != MaterialParser::ParseResult::SUCCESS) return 0;

    uint32_t u32; uint8_t u8; uint64_t u64; bool b; float f;
    utils::CString name;
    parser.getMaterialVersion(&u32);
    parser.getFeatureLevel(&u8);
    parser.getName(&name);
    parser.getShaderModels(&u32);
    parser.getMaterialProperties(&u64);
    parser.getPrecomputedCrc32();
    parser.computeCrc32();
    parser.getMaterialCrc32(&u32);

    BufferInterfaceBlock uib;   parser.getUIB(&uib);
    SamplerInterfaceBlock sib;  parser.getSIB(&sib);
    SubpassInfo subpass;        parser.getSubpasses(&subpass);

    utils::FixedCapacityVector<MaterialConstant> constants;
    parser.getConstants(&constants);
    utils::CString structVar;
    utils::FixedCapacityVector<MaterialPushConstant> pushConstants;
    parser.getPushConstants(&structVar, &pushConstants);

    MaterialParser::BindingUniformInfoContainer bindings;
    parser.getBindingUniformInfo(&bindings);
    MaterialParser::AttributeInfoContainer attrs;
    parser.getAttributeInfo(&attrs);
    MaterialParser::DescriptorBindingsContainer descBindings;
    parser.getDescriptorBindings(&descBindings);
    MaterialParser::DescriptorSetLayoutContainer layout;
    parser.getDescriptorSetLayout(&layout);

    parser.getDepthWriteSet(&b);   parser.getDepthWrite(&b);
    parser.getDoubleSidedSet(&b);  parser.getDoubleSided(&b);
    backend::CullingMode cm;       parser.getCullingMode(&cm);
    TransparencyMode tm;           parser.getTransparencyMode(&tm);
    parser.getColorWrite(&b);      parser.getDepthTest(&b);   parser.getInstanced(&b);
    Interpolation interp;          parser.getInterpolation(&interp);
    VertexDomain vd;               parser.getVertexDomain(&vd);
    MaterialDomain md;             parser.getMaterialDomain(&md);
    UserVariantFilterMask vfm;     parser.getMaterialVariantFilterMask(&vfm);
    Shading shading;               parser.getShading(&shading);
    BlendingMode bm;               parser.getBlendingMode(&bm);
    std::array<backend::BlendFunction, 4> bf; parser.getCustomBlendFunction(&bf);
    parser.getMaskThreshold(&f);
    parser.getAlphaToCoverageSet(&b); parser.getAlphaToCoverage(&b);
    parser.hasShadowMultiplier(&b);
    AttributeBitset attrBits;      parser.getRequiredAttributes(&attrBits);
    RefractionMode rm;             parser.getRefractionMode(&rm);
    RefractionType rt;             parser.getRefractionType(&rt);
    ReflectionMode rfm;            parser.getReflectionMode(&rfm);
    parser.hasCustomDepthShader(&b);
    parser.hasSpecularAntiAliasing(&b);
    parser.getSpecularAntiAliasingVariance(&f);
    parser.getSpecularAntiAliasingThreshold(&f);
    backend::StereoscopicType st;  parser.getStereoscopicType(&st);
    utils::CString src;            parser.getSourceShader(&src);

    // Walk the shader table and decode a bounded number of shaders.
    int budget = 8;
    parser.getMaterialChunk().visitShaders(
            [&](backend::ShaderModel model, Variant variant, backend::ShaderStage stage) {
                if (budget-- <= 0) return;
                filaflat::ShaderContent content;
                parser.getShader(content, model, variant, stage);
            });
    return 0;
}
