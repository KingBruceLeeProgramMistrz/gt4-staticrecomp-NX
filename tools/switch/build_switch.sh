#!/usr/bin/env bash
set -euo pipefail

# Uruchamiaj z katalogu głównego repozytorium gt4-staticrecomp
# Wymaga Dockera (obraz devkitpro/devkita64)

if [ ! -d "third_party/simde" ]; then
    echo "[1/3] Pobieranie SIMDe (SSE4.1 -> ARM64 NEON)..."
    git clone --depth 1 https://github.com/simd-everywhere/simde.git third_party/simde
fi

echo "[2/3] Konfiguracja i kompilacja w kontenerze devkitpro/devkita64..."
docker run --rm -v "$(pwd):/src" -w /src devkitpro/devkita64 bash -lc '
    set -e
    # Zainstaluj portlibs wymagane przez GT4 (Mesa GLES, SDL3 jeśli dostępne lub SDL2, libchdr/zlib)
    dkp-pacman -Syu --noconfirm --needed \
        switch-mesa switch-libdrm_nouveau switch-glad switch-zlib switch-libpng

    cmake -S . -B build-switch \
        -DCMAKE_TOOLCHAIN_FILE=cmake/SwitchToolchain.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DGT4_BUILD_LAUNCHER=OFF \
        -DGT4_ENABLE_GSDX=OFF \
        -DGT4_COREGS_BACKEND=GLES3 \
        -DSIMDE_INCLUDE_DIR=/src/third_party/simde

    cmake --build build-switch -j"$(nproc)"
'

echo "[3/3] Gotowe! Szukaj pliku .nro w katalogu build-switch/"
