#!/usr/bin/env bash
# Build the Galaxy Note10 Lite (SM-N770F, r7) kernel and package it as an AnyKernel3 zip.
#
# Usage: ./build-n770f.sh [options] [TAG]
#   TAG               short name added to the zip, e.g. v28-pinctrl (default: git short hash)
#   --checkpoints     enable EXYNOS_BOOT_CHECKPOINTS (on-screen boot progress)
#   --clean           run "make mrproper" first (full rebuild)
#   --push            after a successful build, push a squashed checkpoint of the tree to
#                     GitHub (refs/heads/uprev-4.14 on origin's push URL)
#   --no-telegram     do not copy the zip to the Telegram Desktop folder
#   -j N              parallel jobs (default 10; keep at or below 12)
#
# Output: /root/kernel/release/N770F-<kernelversion>-<TAG>-AK3.zip (+ copy in Telegram Desktop)
set -euo pipefail

KDIR=/root/kernel/n770f
AK3_TEMPLATE=/root/kernel/ak3-uprev
RELEASE=/root/kernel/release
TELEGRAM="/mnt/c/Users/Lenovo/Downloads/Telegram Desktop"
LOGDIR=/root/kernel/logs
PUSH_BRANCH=uprev-4.14
JOBS=10
CHECKPOINTS=0 CLEAN=0 PUSH=0 TELEGRAM_COPY=1 TAG=""

while [ $# -gt 0 ]; do
	case "$1" in
		--checkpoints) CHECKPOINTS=1 ;;
		--clean) CLEAN=1 ;;
		--push) PUSH=1 ;;
		--no-telegram) TELEGRAM_COPY=0 ;;
		-j) JOBS="$2"; shift ;;
		-h|--help) sed -n '2,16p' "$0"; exit 0 ;;
		-*) echo "unknown option $1" >&2; exit 2 ;;
		*) TAG="$1" ;;
	esac
	shift
done
[ "$JOBS" -le 12 ] || { echo "-j $JOBS is too high; use 12 or less" >&2; exit 2; }

cd "$KDIR"
export ARCH=arm64 PLATFORM_VERSION=13 ANDROID_MAJOR_VERSION=t
HASH=$(git rev-parse --short=12 HEAD)
TAG=${TAG:-$HASH}
mkdir -p "$LOGDIR" "$RELEASE"
LOG="$LOGDIR/build-$(date +%Y%m%d-%H%M%S)-$TAG.log"

echo "== N770F kernel build: branch $(git rev-parse --abbrev-ref HEAD) @ $HASH, tag $TAG, -j$JOBS"
[ "$CLEAN" = 1 ] && make mrproper
make exynos9810-r7_defconfig >/dev/null
make olddefconfig >/dev/null
if [ "$CHECKPOINTS" = 1 ]; then
	./scripts/config --enable EXYNOS_BOOT_CHECKPOINTS
	make olddefconfig >/dev/null
fi

echo "== building (log: $LOG)"
if ! make -j"$JOBS" >"$LOG" 2>&1; then
	echo "!! build failed; last errors:" >&2
	grep -nE "error:|Error [0-9]" "$LOG" | tail -20 >&2 || tail -30 "$LOG" >&2
	exit 1
fi
IMG=arch/arm64/boot/Image
[ -s "$IMG" ] || { echo "!! no $IMG after build" >&2; exit 1; }
KVER=$(make -s kernelversion)

# AnyKernel3 package from a fresh copy of the template
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cp -a "$AK3_TEMPLATE/." "$WORK/"
cp "$IMG" "$WORK/Image"
sed -i "s|^kernel.string=.*|kernel.string=N770F $KVER $TAG ($HASH, permissive, KSU)|" "$WORK/anykernel.sh"
ZIP="$RELEASE/N770F-$KVER-$TAG-AK3.zip"
rm -f "$ZIP"
(cd "$WORK" && zip -qr9 "$ZIP" Image LICENSE META-INF anykernel.sh tools)
echo "== built $ZIP ($(du -h "$ZIP" | cut -f1))"
if [ "$TELEGRAM_COPY" = 1 ] && [ -d "$TELEGRAM" ]; then
	cp "$ZIP" "$TELEGRAM/" && echo "== copied to Telegram Desktop"
fi

if [ "$PUSH" = 1 ]; then
	PUSHURL=$(git remote get-url --push origin)
	echo "== pushing squashed checkpoint to $PUSH_BRANCH"
	REMOTE=$(git ls-remote "$PUSHURL" "refs/heads/$PUSH_BRANCH" | cut -f1)
	git fetch -q "$PUSHURL" "$PUSH_BRANCH"
	if [ "$(git rev-parse 'HEAD^{tree}')" = "$(git rev-parse 'FETCH_HEAD^{tree}')" ]; then
		echo "== GitHub already has this exact tree; nothing to push"
	else
		MSG="checkpoint $TAG: $(git log -1 --format=%s)

Squashed from local $(git rev-parse --abbrev-ref HEAD) at $HASH.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
		C=$(git commit-tree 'HEAD^{tree}' -p "$REMOTE" -m "$MSG")
		git push -q "$PUSHURL" "$C:refs/heads/$PUSH_BRANCH"
		echo "== pushed $C"
	fi
fi
