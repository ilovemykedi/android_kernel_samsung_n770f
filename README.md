# ColorOS port tools (Galaxy Note10 Lite SM-N770F, Galaxy Tab A7 10.4 SM-T500)

Scripts and sources from the ColorOS ports. Kernel sources live on the `uprev-4.14` branch.

## Layout
- `build-n770f.sh`: builds the N770F (r7) kernel and packages an AnyKernel3 zip.
  Options: `--checkpoints`, `--clean`, `--push`, `-j N`; see `--help`.
- `n770f/uprev-tools`: helpers used for the 4.10 -> 4.11 merge (`resolve.py`, `hunks.py`, `addinc.py`, `opp_rcu.py`, ...).
- `n770f/coloros-perm`: `n770f.rc` and `n770f-boot.sh` baked into the ColorOS system (FOD props, AOD, sysbta, dpf).
- `n770f/fodfixer`: FOD fixer KSU module and its overlay source.
- `n770f/aodfix`: AOD/HLPM/DT2W module (`module/`), its source (`src/`) and the stand-in OnePlus display-panel HAL (`dpf/`).
- `n770f/telephony-fix-module`: KSU module v3. It adds the fixed APN database (empty LTE attach APNs filled), a bind mount, and a one-time APN reset.
- `n770f/sysbta-module`: the TrebleDroid system Bluetooth audio KSU module.
- `n770f/full-zip-update-binary.sh`, `taba7/full-zip-update-binary.sh`: installers of the full TWRP zips. Each image is written by `dd` and checked by md5. Offsets are literal numbers, because the TWRP shell does 32-bit arithmetic.
- `taba7/vendor-product-fixes`: vendor/product files for the Tab A7 port:
  - erofs fstab, encryption off
  - SELinux `_debug` cil files
  - VINTF fixes (no SoundTrigger, btconfigstore 1.0, face v2)
  - OEM groups
  - face HAL rc/manifest
  - sysbta audio policy
  - ExtServices overlay
  - product `build.prop`
- `taba7/facehal-shim`: `nwshim.c`, a `ANativeWindow_readFromParcel` stub for Android 13 (build: `clang --target=aarch64-linux-android29 -fPIC -shared -nostdlib -O2 -o libnwshim.so nwshim.c`). The face HAL itself is private and not included; only its init rc and VINTF manifest are.

## Not included
These were left out on purpose: binaries over 20 MB, release zips, and the signing keystore.
- `n770f/telephony-fix-module/system/framework/framework.jar`: ColorOS `framework.jar`, where `android.timezone.TelephonyNetworkFinder.findNetworkByMccMnc` returns null.
- `.../services.jar`: the v3 FOD `services.jar`, where `ColorDisplayService.setColorModeInternal` ignores unsupported modes.
- `.../TeleService.apk`: the `if-eqz` before `getActiveModemCount` in class `c6.c1` is replaced by two nops (35 bytes).
- The face HAL (private): the `android.hardware.biometrics.face-service.facehal` binary and all its libraries.
