// Fuzzes the material-definition (.mat / JSON) front end of matc: template substitution,
// lexer, JSON-ish parser and the per-property processors. Does not run the shader compiler.
#include <filament-matp/Config.h>
#include <filament-matp/MaterialParser.h>

#include <filamat/MaterialBuilder.h>

#include <utils/Status.h>

#include <stddef.h>
#include <stdint.h>
#include <string.h>

#include <memory>

namespace {
class FuzzConfig : public matp::Config {
public:
    Output* getOutput() const noexcept override { return nullptr; }
    Input* getInput() const noexcept override { return nullptr; }
    std::string toString() const noexcept override { return ""; }
    std::string toPIISafeString() const noexcept override { return ""; }
};
}

extern "C" int LLVMFuzzerInitialize(int*, char***) {
    filamat::MaterialBuilder::init();
    return 0;
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size == 0) return -1;
    // The lexer expects a NUL-terminated buffer of `size` bytes plus terminator.
    auto buffer = std::make_unique<char[]>(size + 1);
    memcpy(buffer.get(), data, size);
    buffer[size] = '\0';
    std::unique_ptr<const char[]> constBuffer(buffer.release());
    ssize_t ssize = (ssize_t) size;

    FuzzConfig config;
    matp::MaterialParser parser;
    filamat::MaterialBuilder builder;
    if (!parser.processTemplateSubstitutions(config, ssize, constBuffer).isOk()) return 0;
    parser.parse(builder, config, ssize, constBuffer);
    return 0;
}
