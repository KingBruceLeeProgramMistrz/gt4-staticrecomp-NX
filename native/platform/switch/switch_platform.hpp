// native/platform/switch/switch_platform.hpp
#pragma once

#ifdef __SWITCH__

#include <switch.h>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <string>

// Automatyczne mapowanie x86 SSE4.1 (<smmintrin.h>) na ARM64 NEON przez SIMDe
// Wymaga dodania header-only submodule: third_party/simde
#define SIMDE_ENABLE_NATIVE_ALIASES
#include <simde/x86/sse4.1.h>

namespace gt4::platform::switch_os {

struct SwitchContext {
    int nxlink_sock = -1;
    bool romfs_ok = false;
    bool is_applet_mode = false;
};

inline SwitchContext& get_context() {
    static SwitchContext ctx;
    return ctx;
}

// Wywołaj na samym początku main() przed inicjalizacją SDL3 / CoreGS
inline void init() {
    auto& ctx = get_context();

    // Sieciowe przekierowanie stdout/stderr do nxlink (debugging na żywo po Wi-Fi)
    socketInitializeDefault();
    ctx.nxlink_sock = nxlinkStdio();

    // Sprawdzenie, czy uruchomiono w trybie Full RAM (Title Takeover)
    AppletType at = appletGetAppletType();
    ctx.is_applet_mode = (at != AppletType_Application && at != AppletType_SystemApplication);
    if (ctx.is_applet_mode) {
        std::fprintf(stderr,
            "[GT4-SWITCH] UWAGA: Uruchomiono w Applet Mode (~440 MB RAM). "
            "Uruchom przez Title Takeover (przytrzymaj R przy odpalaniu gry), inaczej zabraknie pamięci!\n");
    }

    // Katalog roboczy na karcie SD
    std::filesystem::create_directories("sdmc:/switch/gt4recomp/saves");
    std::filesystem::create_directories("sdmc:/switch/gt4recomp/shaders");

    // Inicjalizacja romfs (opcjonalnie dla wbudowanych shaderów GLES)
    Result rc = romfsInit();
    ctx.romfs_ok = R_SUCCEEDED(rc);
}

inline void shutdown() {
    auto& ctx = get_context();
    if (ctx.romfs_ok) {
        romfsExit();
    }
    if (ctx.nxlink_sock >= 0) {
        close(ctx.nxlink_sock);
        ctx.nxlink_sock = -1;
    }
    socketExit();
}

inline std::string data_root() {
    return "sdmc:/switch/gt4recomp";
}

// Ścieżki wyszukiwania obrazu gry (uwzględnia limit 4 GB FAT32 -> preferuj .chd lub split .iso.0)
inline std::string find_disc_image() {
    namespace fs = std::filesystem;
    const char* candidates[] = {
        "sdmc:/switch/gt4recomp/gt4.chd",
        "sdmc:/switch/gt4recomp/gt4_spec2.chd",
        "sdmc:/switch/gt4recomp/gt4.iso.0",
        "sdmc:/switch/gt4recomp/gt4.iso"
    };
    for (const char* path : candidates) {
        if (fs::exists(path)) {
            return std::string(path);
        }
    }
    return {};
}

// Prosty zamiennik Win32 VirtualAlloc/mmap dla pamięci PS2 (32 MB EE RAM + 16 KB Scratchpad)
inline void* alloc_aligned(size_t alignment, size_t size) {
    void* ptr = nullptr;
    if (posix_memalign(&ptr, alignment, size) != 0) {
        return nullptr;
    }
    return ptr;
}

} // namespace gt4::platform::switch_os

#endif // __SWITCH__
