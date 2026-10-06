#!/usr/bin/env bash
# Build Vibepollo (with the PyroWave encoder) and its MSI on Mark-PC.
# Run from an MSYS2 UCRT64 shell: bash markpc/build.sh [--deps] [--update]
#   --deps    install/refresh the MSYS2 packages first
#   --update  merge Nonary/Vibepollo master into this fork before building
# Output: build/cpack_artifacts/Vibepollo.msi  (install with markpc/install.ps1)
set -euo pipefail
cd "$(dirname "$0")/.."

T=mingw-w64-ucrt-x86_64
for a in "$@"; do case "$a" in
  --deps)
    pacman -Syu --noconfirm
    pacman -S --needed --noconfirm git $T-boost $T-cmake $T-ninja $T-cppwinrt $T-curl-winssl \
      $T-libjpeg-turbo $T-libpng $T-libwebp $T-miniupnpc $T-onevpl $T-openssl $T-opus \
      $T-toolchain $T-MinHook $T-nsis $T-nodejs $T-nlohmann-json
    ;;
  --update)
    git remote get-url upstream >/dev/null 2>&1 || git remote add upstream https://github.com/Nonary/Vibepollo.git
    git fetch upstream && git merge --no-edit upstream/master
    git submodule update --init --recursive --jobs 8
    ;;
esac; done

# WiX 3.14 standalone binaries (the WiX installer needs .NET 3.5, the binaries don't).
export WIX='C:\tools\wix314\'
export PATH="/c/tools/wix314:$PATH"
# A PSModulePath inherited from PowerShell 7 breaks Windows PowerShell 5.1 module
# autoload (Get-FileHash "not recognized") in the driver-packaging step.
unset PSModulePath

# Stop anything holding build/sunshine.exe open or the link step fails.
cmake -B build -G Ninja -S . -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTS=OFF -DBUILD_DOCS=OFF
grep -q 'SUNSHINE_ENABLE_PYROWAVE:BOOL=ON' build/CMakeCache.txt || { echo "PyroWave is disabled in this build"; exit 1; }
cmake --build build --target package_msi
ls -la build/cpack_artifacts/Vibepollo.msi
