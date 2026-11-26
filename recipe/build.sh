#!/usr/bin/env bash
set -euo pipefail

: "${ZIG_TARGET:?recipe.yaml has no Zig target for ${target_platform}; add it to zig_target}"

# Keep both Zig caches inside the work directory. The zig activation script
# points the global cache at $HOME, which would let an earlier build's
# downloads satisfy this one.
export ZIG_GLOBAL_CACHE_DIR="${SRC_DIR}/.zig-global-cache"
export ZIG_LOCAL_CACHE_DIR="${SRC_DIR}/.zig-local-cache"

# Hand the dependencies to Zig without network access. `zig fetch <dir>`
# stores a local directory in the global cache under its package hash, keeping
# only the files the package declares and computing the hash from them. Since
# Zig 0.17 it no longer unpacks it into ./zig-pkg; `zig build --fetch` does
# that, for the hashes build.zig.zon asks for. Those are in the cache by now,
# so nothing is downloaded (and the build has no network to download from).
# `--system` below makes Zig read packages from ./zig-pkg and nowhere else: a
# wrong or missing source stops the build instead of being fetched.
for dep in zig-deps/*/; do
    zig fetch "${dep}"
done
zig build --fetch

# -Dcpu=baseline: the lowest CPU of the target (x86-64-v1 on linux-64 and
# win-64, core2 on osx-64, generic armv8 on linux-aarch64, apple_m1 on
# osx-arm64), not the CPU of the build machine.
zig build \
    --system "${SRC_DIR}/zig-pkg" \
    --prefix "${PREFIX}" \
    -Doptimize=ReleaseFast \
    -Dtarget="${ZIG_TARGET}" \
    -Dcpu=baseline \
    -j"${CPU_COUNT:-1}" \
    --summary all

# The work directory is copied into every package that inherits this build;
# the Zig caches are large and of no use there.
rm -rf "${ZIG_GLOBAL_CACHE_DIR}" "${ZIG_LOCAL_CACHE_DIR}"
