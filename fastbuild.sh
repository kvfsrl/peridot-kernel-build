#!/usr/bin/env bash
#
# FAST out-of-tree rebuild of msm_drm.ko only.
#
# After a full CI build, download the "buildstate-peridot-kernel-<run>" artifact
# and unzip it into this repo root. It restores:
#   out/.config, out/Module.symvers, out/include/**, out/arch/arm64/include/**,
#   out/scripts/** and the companion modules' Module.symvers (sync_fence,
#   hw_fence, msm_ext_display, mmrm, securemsm) under modules/..., plus the
#   display module's own Module.symvers under display-drivers/.
#
# With the kernel source checked out at the SAME SHA (build.sh pins
# GuidixX/kernel_xiaomi_sm8635 @ 16.2; the out/Module.symvers' kernel-sha must
# match, else modversions CRC diverge), this rebuilds ONLY the display techpack:
# no vmlinux, no full modules pass -> ~1-4 min per iteration.
#
# Usage:
#   gh run download <run-id> --repo kvfsrl/peridot-kernel-build \
#       -n buildstate-peridot-kernel-<run-id>
#   unzip -o buildstate-peridot-kernel-<run-id>.zip   # into this repo root
#   bash fastbuild.sh
#
# Result: out/msm_drm.ko  (replace only that file in the device vendor_dlkm)

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KERNEL_DIR="${KERNEL_DIR:-$ROOT/kernel}"
MODULES_DIR="${MODULES_DIR:-$ROOT/modules}"
DISPLAY_ROOT="${DISPLAY_ROOT:-$ROOT/display-drivers}"
OUT="${OUT:-$ROOT/out}"
ARCH=arm64
JOBS="${JOBS:-$(nproc --ignore=2)}"
MM="$MODULES_DIR/qcom/opensource"
MMD="$MM/mm-drivers"
MMRM_SYM="$MM/mmrm-driver/driver"
SECURE="$MM/securemsm-kernel"
SYNC="$MMD/sync_fence"
HW="$MMD/hw_fence"
EXT="$MMD/msm_ext_display"

if [[ -n "${CLANG_DIR:-}" ]]; then
  export CC="$CLANG_DIR/bin/clang"
  export PATH="$CLANG_DIR/bin:$PATH"
else
  export CC="$(command -v clang)"
fi
export LLVM=1
export LLVM_IAS=1
export SUBARCH=arm64
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export STRIP=llvm-strip
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export READELF=llvm-readelf
export LOCALVERSION=

[[ -f "$KERNEL_DIR/Makefile" ]] || { echo "kernel tree missing at $KERNEL_DIR"; exit 1; }
[[ -f "$DISPLAY_ROOT/msm/Kbuild" ]] || { echo "display source missing at $DISPLAY_ROOT/msm"; exit 1; }
[[ -f "$OUT/Module.symvers" ]] || { echo "out/Module.symvers missing - restore the buildstate artifact first"; exit 1; }
grep -q '^CONFIG_LOCALVERSION=' "$OUT/.config" || { echo "out/.config missing"; exit 1; }

START=$(date +%s)

echo "[*] modules_prepare"
make -C "$KERNEL_DIR" O="$OUT" ARCH=$ARCH modules_prepare 2>&1 | tail -2

echo "[*] build msm_drm (display techpack only)"
make -C "$KERNEL_DIR" O="$OUT" -j"$JOBS" ARCH=$ARCH \
    M="$DISPLAY_ROOT" DISPLAY_ROOT="$DISPLAY_ROOT" OUT="$OUT" \
    KERNEL_SRC="$KERNEL_DIR" KERNEL_ROOT="$KERNEL_DIR" \
    KBUILD_EXTRA_SYMBOLS="$SYNC/Module.symvers $HW/Module.symvers $EXT/Module.symvers $MMRM_SYM/Module.symvers $SECURE/Module.symvers" \
    CONFIG_ARCH_PINEAPPLE=y CONFIG_DRM_MSM=y CONFIG_DRM_MSM_SDE=y CONFIG_SYNC_FILE=y CONFIG_DRM_MSM_DSI=y \
    CONFIG_DRM_MSM_DP=y CONFIG_DRM_MSM_DP_MST=y CONFIG_DSI_PARSER=y CONFIG_QCOM_MDSS_PLL=y \
    CONFIG_DRM_SDE_RSC=y CONFIG_DRM_SDE_WB=y CONFIG_GKI_DISPLAY=y CONFIG_MSM_EXT_DISPLAY=y \
    CONFIG_MSM_MMRM=y CONFIG_DISPLAY_BUILD=m CONFIG_HDCP_QSEECOM=y CONFIG_QTI_HW_FENCE=y \
    CONFIG_QCOM_SPEC_SYNC=y CONFIG_QCOM_WCD939X_I2C=y MI_DISPLAY_MODIFY=y \
    modules 2>&1 | tee "$OUT/build.log"

llvm-strip --strip-debug "$DISPLAY_ROOT/msm_drm.ko" 2>/dev/null || true
cp -f "$DISPLAY_ROOT/msm_drm.ko" "$OUT/msm_drm.ko"
ls -la "$OUT/msm_drm.ko" || { echo "ERROR: msm_drm.ko not produced"; exit 1; }

END=$(date +%s)
echo "[*] fastbuild done in $((END - START))s -> out/msm_drm.ko"