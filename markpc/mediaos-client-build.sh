#!/usr/bin/env bash
# Build Nonary's moonlight-qt (release/6.1.0-vrr18, the client matched to Vibepollo's
# PyroWave protocol) on mediaos with libplacebo + PyroWave, and install it as
# ~/.local/bin/moonlight-pyro. ~/.local/bin/moonlight-qt is a symlink to it, which
# is what mediaos-direct runs on the bare KMS display (HDR).
# No sudo needed: the two missing -dev packages are unpacked into a local prefix.
set -e
B=~/.local/share/mediaos/moonlight-pyro; mkdir -p $B && cd $B
if [ ! -d dev/usr/include/libplacebo ] || [ ! -d dev/usr/include/x86_64-linux-gnu/libavformat ]; then
  mkdir -p debs && (cd debs && apt-get download libplacebo-dev libavformat-dev >/dev/null)
  for d in debs/*.deb; do dpkg -x "$d" dev; done
  PC=dev/usr/lib/x86_64-linux-gnu/pkgconfig/libplacebo.pc
  sed -i "s#^prefix=.*#prefix=$B/dev/usr#" $PC
  # lcms2 is a private dependency; its -dev package isn't installed and isn't
  # needed for dynamic linking, but pkg-config would otherwise reject libplacebo
  # and qmake would silently build without the Vulkan renderer (and PyroWave).
  sed -i "s/^Requires.private:.*/Requires.private: vulkan/" $PC
  ln -sf /usr/lib/x86_64-linux-gnu/libplacebo.so.360 dev/usr/lib/x86_64-linux-gnu/libplacebo.so
fi
export PKG_CONFIG_PATH=$B/dev/usr/lib/x86_64-linux-gnu/pkgconfig
INC="-isystem $B/dev/usr/include/x86_64-linux-gnu"
[ -d tree ] || git clone -q --recurse-submodules -b release/6.1.0-vrr18 https://github.com/Nonary/moonlight-qt.git tree
cd tree; git log -1 --format='%h %s'
mkdir -p build && cd build
rm -rf .qmake.stash app/Makefile*
qmake6 ../moonlight-qt.pro CONFIG+=release "QMAKE_CFLAGS+=$INC" "QMAKE_CXXFLAGS+=$INC" >/dev/null 2>&1
grep -q -- -DHAVE_PYROWAVE app/Makefile.Release || { echo "BUILD_FAILED: PyroWave not enabled (libplacebo not found?)"; exit 1; }
# Always clean: qmake doesn't recompile objects when DEFINES change, which once
# left a binary whose PyroWave path was the "not available in this build" stub.
make clean >/dev/null 2>&1 || true
if ! make -j"$(nproc)" >make.log 2>&1; then echo BUILD_FAILED; grep -iE "error" make.log | head -25; exit 1; fi
install -m755 app/moonlight ~/.local/bin/moonlight-pyro
[ -L ~/.local/bin/moonlight-qt ] || { [ -e ~/.local/bin/moonlight-qt ] && mv ~/.local/bin/moonlight-qt ~/.local/bin/moonlight-qt.prev; ln -s moonlight-pyro ~/.local/bin/moonlight-qt; }
echo BUILD_DONE
