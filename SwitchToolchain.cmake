# cmake/SwitchToolchain.cmake
# Toolchain dla Nintendo Switch (Atmosphère / Horizon OS) przez devkitA64

if(NOT DEFINED ENV{DEVKITPRO})
    message(FATAL_ERROR "Zmienna środowiskowa DEVKITPRO nie jest ustawiona. Użyj kontenera devkitpro/devkita64 lub zainstaluj devkitPro.")
endif()

set(DEVKITPRO "$ENV{DEVKITPRO}")
set(DEVKITA64 "${DEVKITPRO}/devkitA64")
set(PORTLIBS  "${DEVKITPRO}/portlibs/switch")
set(LIBNX     "${DEVKITPRO}/libnx")

set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR aarch64)
set(NINTENDO_SWITCH TRUE CACHE BOOL "Building for Nintendo Switch (Horizon OS)")

set(CMAKE_C_COMPILER   "${DEVKITA64}/bin/aarch64-none-elf-gcc")
set(CMAKE_CXX_COMPILER "${DEVKITA64}/bin/aarch64-none-elf-g++")
set(CMAKE_AR           "${DEVKITA64}/bin/aarch64-none-elf-ar" CACHE FILEPATH "Archiver")
set(CMAKE_RANLIB       "${DEVKITA64}/bin/aarch64-none-elf-ranlib" CACHE FILEPATH "Ranlib")

set(CMAKE_FIND_ROOT_PATH "${DEVKITA64}" "${PORTLIBS}" "${LIBNX}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)

# Flagi sprzętowe pod Tegra X1 (Cortex-A57, ARMv8-A + NEON)
set(SWITCH_ARCH_FLAGS "-march=armv8-a+crc+crypto+simd -mtune=cortex-a57 -mtp=soft -fPIE")
set(SWITCH_DEFS "-D__SWITCH__ -DGT4_PLATFORM_SWITCH=1 -DGT4_DISABLE_GSDX=1 -DGT4_USE_GLES3=1 -DSIMDE_ENABLE_NATIVE_ALIASES")

set(CMAKE_C_FLAGS_INIT   "${SWITCH_ARCH_FLAGS} ${SWITCH_DEFS} -ffunction-sections -fdata-sections")
set(CMAKE_CXX_FLAGS_INIT "${SWITCH_ARCH_FLAGS} ${SWITCH_DEFS} -ffunction-sections -fdata-sections -fno-rtti")
set(CMAKE_EXE_LINKER_FLAGS_INIT "-specs=${LIBNX}/switch.specs -g ${SWITCH_ARCH_FLAGS} -Wl,-Map,gt4recomp.map -L${PORTLIBS}/lib -L${LIBNX}/lib")

include_directories(SYSTEM
    "${LIBNX}/include"
    "${PORTLIBS}/include"
    "${PORTLIBS}/include/SDL3"
)

# Pomocnicza funkcja generująca .nacp i .nro z targetu ELF
function(gt4_create_switch_nro TARGET_NAME APP_TITLE APP_AUTHOR APP_VERSION)
    set(NACP_FILE "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.nacp")
    set(NRO_FILE  "${CMAKE_CURRENT_BINARY_DIR}/${TARGET_NAME}.nro")

    add_custom_command(
        OUTPUT "${NACP_FILE}"
        COMMAND "${DEVKITPRO}/tools/bin/nacptool" --create "${APP_TITLE}" "${APP_AUTHOR}" "${APP_VERSION}" "${NACP_FILE}"
        COMMENT "Generowanie metadanych NACP dla ${TARGET_NAME}"
    )

    add_custom_command(
        OUTPUT "${NRO_FILE}"
        DEPENDS "${TARGET_NAME}" "${NACP_FILE}"
        COMMAND "${DEVKITPRO}/tools/bin/elf2nro" "$<TARGET_FILE:${TARGET_NAME}>" "${NRO_FILE}" --nacp="${NACP_FILE}"
        COMMENT "Pakowanie Nintendo Switch homebrew: ${NRO_FILE}"
    )

    add_custom_target(${TARGET_NAME}_nro ALL DEPENDS "${NRO_FILE}")
endfunction()
