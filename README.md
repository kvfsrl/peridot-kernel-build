# peridot-kernel-build

CI untuk membangun `msm_drm.ko` + sekumpulan modul `vendor_dlkm` untuk
**Xiaomi Redmi Turbo 3 (`peridot`, Qualcomm SM8635, Android 14)**.

## Asal-usul

Repo ini adalah **rekonstruksi** `hoshikv/peridot-kernel-build`, yang tidak bisa
di-clone lagi karena akun GitHub-nya tersuspend. Yang dipulihkan:

- `build.sh` — **isi script aslinya** (605 baris), bukan rekonstruksi.
  Diambil dari cache `cat /tmp/build.sh` dan diverifikasi terhadap run-log CI
  (semua penanda `[*] build ...` cocok).
- `.github/workflows/build.yml` — workflow **ditulis ulang** dari run-log, karena
  YAML aslinya tidak pernah ada di disk.

## Yang dipulihkan

| | |
|---|---|
| Toolchain | Android clang `clang-r530567`, `LLVM=1`, `ARCH=arm64` |
| Kernel | `GuidixX/kernel_xiaomi_sm8635` branch **`16.2`** (SUBLEVEL 174 → di-bump 175) |
| KMI | `6.1.175-android14-11-ga3b9c44908dd-ab13320413` |
| Modul | msm_drm, touch, audio, mmrm, securemsm, sync/hw_fence, msm_ext_display, qti battery, frameboost (7), hybridswap (3), haptic |

## Sumber input (semua publik, tanpa token)

| Komponen | Sumber |
|---|---|
| kernel | `GuidixX/kernel_xiaomi_sm8635` @ `16.2` |
| modules (mm-drivers, display, touch, audio, mmrm, securemsm) | `GuidixX/kernel_xiaomi_sm8635-modules` @ `16.2` |
| frameboost | `kvfsrl/vendor_frameboost-drivers` |
| hybridswap | `kvfsrl/vendor_oplus-hybridswap-driver` |
| haptic | `kvfsrl/vendor_opensource-haptic-driver-peridot` |

Bedanya dengan build CI yang diblokir: display/touch/audio dulu di-clone sebagai
tiga repo `hoshikv` terpisah. Sekarang ketiganya diambil dari
`qcom/opensource/{display-drivers,touch-drivers,audio-kernel}` di dalam modules
repo GuidixX — isinya sama persis (termasuk `msm/Kbuild` dan
`goodix_berlin_driver`/`focaltech_3683g`/`xiaomi` untuk touch), tapi tidak
perlu token dan tidak ikut mati.

## Kenapa branch `16.2` dan bukan `17`

Modul harus punya `vermagic` + CRC symbol yang sama persis dengan kernel yang
terpasang di perangkat. Perangkat menjalankan 6.1.175. Branch `16.2` adalah
6.1.174 dan `build.sh` menaikkan `SUBLEVEL` ke 175 supaya cocok; branch `17`
sudah 6.1.176 dan **modulnya tidak akan mau dimuat**. Ini persis configure yang
dipakai build sebelumnya.

## Cara build

```bash
# lokal
CLANG_DIR=/path/clang-r530567 MODULES_BRANCH=16.2 ./build.sh
```

Semua direktori bisa dioverride lewat env var (`KERNEL_DIR`, `MODULES_DIR`,
`FB_DIR`, `HS_DIR`, `HAPTIC_ROOT`, `CLANG_DIR`, `OUT`, `JOBS`).

## Catatan

- step `vendor_dlkm.img` sengaja dilewati; yang dipakai hanya `Image` + `.ko`.
- `DEBUG_INFO*` dimatikan supaya `msm_drm.ko` tidak 45 MB.
- `MODULE_SIG*` dimatikan supaya modul tak bertanda tangan bisa dimuat.
- Run CI terakhir di akun lama **gagal** karena meng-clone
  `vendor_oplus-missing-drivers` tanpa token. `build.sh` di sini **tidak**
  memakai repo itu, jadi masalah tersebut tidak muncul. Kalau nanti dibutuhkan,
  clone manual dulu lalu arahkan lewat env var.
