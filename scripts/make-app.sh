#!/bin/bash
# Packages the SwiftPM executable into a real Softplan.app bundle.
#
# `swift build` alone produces a bare Mach-O binary, and macOS cannot attach an
# icon to one of those — the Dock shows the generic placeholder. Wrapping it in
# a bundle with an Info.plist and a compiled icon is what makes the logo appear.
#
# Builds into dist.noindex/ and installs to ~/Applications. Spotlight indexes
# every app bundle it can see, so a build copy left lying in the project shows
# up in search beside the installed one — several Softplan.app hits for one
# app. A directory whose name ends in .noindex is skipped by the indexer, so
# the installed bundle is the only one that surfaces.
#
#   ./scripts/make-app.sh            # debug
#   ./scripts/make-app.sh release    # release
#   SOFTPLAN_NO_INSTALL=1 ./scripts/make-app.sh release   # build only
set -euo pipefail

CONFIG="${1:-debug}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/Softplan"
APP="$ROOT/dist.noindex/Softplan.app"
INSTALLED="$HOME/Applications/Softplan.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Softplan"

# SwiftPM emits declared resources (the header app mark) into a sibling bundle
# next to the binary; without it Bundle.module has nothing to find at runtime.
BUNDLE="$(dirname "$BIN")/Softplan_Softplan.bundle"
if [ -d "$BUNDLE" ]; then
    cp -R "$BUNDLE" "$APP/Contents/Resources/"
else
    echo "warning: $BUNDLE missing — the header logo will not render" >&2
fi

# macOS 26 renders a bare AppIcon.icns with the legacy inset — noticeably
# smaller than its neighbours in the Dock. Compiling the asset catalog instead
# produces an Assets.car, which the system treats as a modern icon. Xcode is
# not always the selected toolchain, so honour DEVELOPER_DIR, then xcode-select,
# then the default install location.
DEV="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null)}"
if [ ! -x "$DEV/usr/bin/actool" ] && [ -x "/Applications/Xcode.app/Contents/Developer/usr/bin/actool" ]; then
    DEV="/Applications/Xcode.app/Contents/Developer"
fi
if [ -n "$DEV" ] && [ -x "$DEV/usr/bin/actool" ]; then
    DEVELOPER_DIR="$DEV" "$DEV/usr/bin/actool" "$ROOT/Assets.xcassets" \
        --compile "$APP/Contents/Resources" \
        --platform macosx \
        --minimum-deployment-target 14.0 \
        --app-icon AppIcon \
        --output-partial-info-plist "$(mktemp -t softplan-icon)" \
        --output-format human-readable-text >/dev/null
    echo "icon: compiled asset catalog (Assets.car)"
else
    cp "$ROOT/App/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
    echo "icon: legacy .icns fallback (no Xcode found)"
fi

cp "$ROOT/App/Info.plist" "$APP/Contents/Info.plist"

printf 'APPL????' > "$APP/Contents/PkgInfo"

# Release builds keep a debug map in the symbol table: the absolute path of
# every source directory and object file on the machine that built them. Strip
# it (and local symbols) so a published download does not carry the builder's
# folder layout. Must happen before signing, which covers the final bytes.
if [ "$CONFIG" = "release" ]; then
    strip -S -x "$APP/Contents/MacOS/Softplan"
fi

# Ad-hoc signature. The bundle claims no entitlements, so nothing here needs
# real provisioning.
codesign --force --sign - "$APP"

touch "$APP"
echo "built $APP"

# release.sh only wants the bundle to zip; leave the installed copy alone.
if [ "${SOFTPLAN_NO_INSTALL:-0}" = "1" ]; then
    exit 0
fi

# Install over any previous copy so the bundle Spotlight and the Dock launch is
# never a stale build. Quit Softplan first if it is running: replacing the
# bundle under a live process leaves it running the old code until relaunch.
mkdir -p "$HOME/Applications"
rm -rf "$INSTALLED"
cp -R "$APP" "$INSTALLED"
touch "$INSTALLED"
echo "installed $INSTALLED"
