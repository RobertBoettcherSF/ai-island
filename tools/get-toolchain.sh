#!/bin/sh
# Opt-in download of the shared AdaWebPack toolchain (GNAT-LLVM 24).
# Not run by make, make test, or tools/build-wasm.sh.
# Run it only after you agree: the packages are large and the link is slow.
# Installs to ${ADAWEBPACK:-$HOME/toolchains/adawebpack-24}. One copy per computer.
# Needs, once: sudo apt install rpm2cpio cpio lld libedit2
set -e
A=${ADAWEBPACK:-$HOME/toolchains/adawebpack-24}
if [ -x "$A/usr/bin/llvm-gcc" ]; then
  echo "Already installed at $A"
  exit 0
fi
mkdir -p "$A/lib"
cd "$A"
F=https://archives.fedoraproject.org/pub/archive/fedora/linux/releases/40/Everything/x86_64/os/Packages
for U in https://github.com/godunko/adawebpack/releases/download/24.0.0/adawebpack-24.0.0-git.fc40.x86_64.rpm \
         $F/l/llvm16-libs-16.0.6-7.fc40.x86_64.rpm \
         $F/c/clang16-libs-16.0.6-5.fc40.x86_64.rpm; do
  echo "Downloading $U"
  curl -sSL "$U" | rpm2cpio | cpio -idm --quiet
done
cp -a usr/lib64/llvm16/lib/libLLVM-16.so usr/lib64/llvm16/lib/libclang-cpp.so.16 lib/
if [ ! -e /usr/lib/x86_64-linux-gnu/libedit.so.0 ]; then
  ln -sf /usr/lib/x86_64-linux-gnu/libedit.so.2 lib/libedit.so.0
fi
# llvm-gcc is itself an Ada program and needs the GNAT 14 runtime.
if ! ldconfig -p | grep -q libgnat-14.so; then
  alr -n install --prefix="$PWD/gnat14" gnat_native=14.2.1
  cp "$(find gnat14 -name libgnat-14.so | head -1)" lib/
fi
rm -rf usr/lib64 gnat14
echo "Toolchain ready in $A"
