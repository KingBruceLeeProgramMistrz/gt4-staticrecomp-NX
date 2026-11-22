# AGENT-BRIEF-SWITCH-PORT: Nintendo Switch (Horizon OS / .nro) Port

## Cel
Przeportowanie natywnego runtime'u `GT4Recomp` (bez launchera desktopowego i bez zewnętrznego procesu `gt4-gs.exe`) na Nintendo Switch (Atmosphère / Horizon OS, `aarch64`, `libnx`) jako samodzielnego homebrew `.nro`.

## Ograniczenia sprzętowe i systemowe (twarde reguły)
1. **CPU:** ARMv8-A 64-bit (Cortex-A57, 3 rdzenie użytkowe). Brak x86-64 i brak natywnego SSE4.1.
2. **Brak wieloprocesowości:** `gt4-gs.exe` (GSdx) musi zostać całkowicie wyłączony przy `GT4_PLATFORM_SWITCH=1`. Jedyny wspierany renderer to wbudowany **CoreGS 2.0**.
3. **Brak Vulkan 1.2 na Horizon OS:** CoreGS 2.0 musi otrzymać alternatywny backend graficzny **OpenGL ES 3.0** (Mesa/Nouveau + EGL + SDL3/SDL2), wzorowany na podejściu z `GT3-revisited-switch`.
4. **RAM:** Wymagany tryb Title Takeover (~3.2 GB). Nie wolno alokować zbędnych buforów pośrednich ani ładować pełnego ISO do pamięci.
5. **System plików (FAT32):** GT4 NTSC-U v2.00 to płyta DVD-9 (~5.5 GB), więc plik przekracza limit 4 GB na FAT32. Należy dodać warstwę odczytu dla dzielonych obrazów (`.iso.0` + `.iso.1`) lub kontenera `.chd` (`libchdr`).

## Plan etapów (realizuj ściśle po kolei, weryfikując kompilację po każdym etapie)

### Etap 1: Abstrakcja platformy i kompilacja CPU (EE + VU0/VU1) na ARM64
- Przeskanuj `CMakeLists.txt` oraz `native/` pod kątem zależności Win32 (`windows.h`, `VirtualAlloc`, `_aligned_malloc`, `QueryPerformanceCounter`, Win32 threads/sockets).
- Wydziel je do warstwy POSIX/`libnx` pod `#ifdef __SWITCH__` (skorzystaj z `native/platform/switch/switch_platform.hpp`).
- Podmień wszystkie bezpośrednie inkludy `<smmintrin.h>` / `<emmintrin.h>` / `<xmmintrin.h>` na wariant wspierający `SIMDe` (`#ifdef __SWITCH__ #include <simde/x86/sse4.1.h> #endif`).
- Zidentyfikuj kod w języku **Rust** (20.7% repo):
  - Jeśli Rust służy wyłącznie do launchera lub narzędzi build-time (`naga`), zostaw go na hoście (x86-64) i nie kompiluj na Switcha.
  - Jeśli fragmenty Rust wchodzą w skład runtime'u CoreGS 2.0, przygotuj target `aarch64-nintendo-switch-freestanding` lub wydziel je do równoważnego modułu C++.
- **Kryterium ukończenia:** Linkowanie binarnego headless `.elf` (bez grafiki) dla `aarch64-none-elf` kończy się bez błędów.

### Etap 2: Konwersja shaderów CoreGS 2.0 na GLSL ES 3.00 przez `naga`
- Wykorzystaj istniejący w repozytorium pipeline `naga` do wygenerowania na etapie builda (host) wariantów shaderów dla **GLSL ES 300** (z zapisem do wygenerowanego nagłówka C++, analogicznie do `tools/switch/generate_gles_shaders.py` z `GT3-revisited-switch`).
- Zweryfikuj ograniczenia GLES 3.0 na Mesa/Nouveau: brak compute shaders (chyba że przejdziesz na GLES 3.1/3.2), brak `gl_ClipDistance`, jawne kwalifikatory precyzji (`precision highp float;`), statyczne bindingi UBO.

### Etap 3: Backend CoreGS 2.0 -> OpenGL ES 3.0 (Mesa/Nouveau)
- Wydziel abstrakcję RHI w CoreGS 2.0 (jeśli obecnie wywołania Vulkan są wplecione bezpośrednio w logikę GS).
- Zaimplementuj backend GLES 3.0 z kontekstem EGL/SDL:
  - Stała rozdzielczość wewnętrzna 1x PS2 lub 720p (handheld).
  - Obsługa tekstur paletowych (CLUT) i swizzlingu GS przy minimalnej liczbie przełączeń FBO.
- **Kryterium ukończenia:** Gra bootuje na Switchu (lub w emulatorze Ryujinx/Eden do szybkich testów PC przed wgraniem na konsolę), wyświetla ekran tytułowy i menu GT4.

### Etap 4: Sterowanie, audio i zapis na karcie SD
- Podłącz wejście Joy-Con / Pro Controller przez SDL3 (mapowanie DualShock 2, opcjonalny analogowy gaz/hamulec na prawym drążku, ponieważ spusty ZL/ZR na Switchu są cyfrowe!).
- Skieruj zapisy karty pamięci (crash-safe memcard) na `sdmc:/switch/gt4recomp/saves/`.
- Dodaj obsługę dzielonego `.iso` (`.iso.0` + `.iso.1`) lub `libchdr` w czytniku wolumenu GT4.

### Etap 5: Optymalizacje pod Tegra X1 (przeniesione z doświadczeń `GT3-revisited-switch`)
1. **Agresywny batching prymitywów i palet:** Rozwiąż znany problem CoreGS 2.0, w którym zmiany palet rozbijają rysowanie na zbyt wiele draw calli (cel: poniżej 500–600 draw calli na klatkę).
2. **Cache'owanie UBO:** Aktualizuj `glBufferSubData` wyłącznie przy faktycznej zmianie macierzy/stanu GS (unikaj stallów potoku Mesa).
3. **Przełączniki wydajnościowe w konfiguracji Switcha:**
   - Domyślne wyłączenie lusterka wstecznego (oszczędza drugi przebieg renderowania sceny).
   - Ograniczenie efektów post-processingu (motion blur, heat haze, depth of field w powtórkach).
   - Opcjonalny limit 30 FPS z równym frame-pacingiem jako tryb awaryjny dla nocnych torów miejskich.
