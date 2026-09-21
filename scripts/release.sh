#!/bin/bash
# Cuts a Softplan release: version bump, tests, a zipped app, a git tag, and
# the GitHub Release people download from.
#
#   ./scripts/release.sh 1.0.1
#
# Before running it, add a "## [1.0.1] - YYYY-MM-DD" section to CHANGELOG.md:
# that section becomes the release notes, and the script refuses to run
# without one.
#
# Publishing the GitHub Release uses the GitHub CLI (`brew install gh`, then
# `gh auth login`). Without it, everything up to and including pushing the tag
# still happens, and the script prints the one manual step that is left.
set -euo pipefail

VERSION="${1:-}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PLIST="App/Info.plist"
TAG="v$VERSION"
OUT="dist.noindex/release"
ZIP_NAME="Softplan-$VERSION.zip"

die() { echo "error: $*" >&2; exit 1; }
plist() { /usr/libexec/PlistBuddy -c "$1" "$PLIST"; }

# --- Preconditions: a release must be reproducible from exactly one commit ---

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] \
    || die "usage: $0 MAJOR.MINOR.PATCH   (for example: $0 1.0.1)"
[ -z "$(git status --porcelain)" ] \
    || die "commit or stash your changes first; a release has to match a commit"
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] \
    || die "releases are cut from main"

git fetch --quiet --tags origin
if git rev-parse --quiet --verify "refs/tags/$TAG" > /dev/null; then
    die "$TAG already exists; pick the next version"
fi

grep -q "^## \[$VERSION\]" CHANGELOG.md \
    || die "CHANGELOG.md has no '## [$VERSION]' section; write the release notes first"

# --- Version bump, committed on its own so the tag points at it ---

CURRENT="$(plist "Print :CFBundleShortVersionString")"
if [ "$VERSION" != "$CURRENT" ]; then
    NEWEST="$(printf '%s\n%s\n' "$CURRENT" "$VERSION" | sort -V | tail -1)"
    [ "$NEWEST" = "$VERSION" ] || die "$VERSION is older than the current $CURRENT"

    BUILD="$(plist "Print :CFBundleVersion")"
    plist "Set :CFBundleShortVersionString $VERSION"
    plist "Set :CFBundleVersion $((BUILD + 1))"
    git add "$PLIST"
    git commit --quiet -m "Release $VERSION"
    echo "version: $CURRENT -> $VERSION (build $((BUILD + 1)))"
else
    echo "version: $VERSION is already set in $PLIST"
fi

# --- Tests, then the app ---

# XCTest ships with Xcode, not the Command Line Tools. Borrow Xcode for this
# run if it is installed but not the selected toolchain.
if [ -z "${DEVELOPER_DIR:-}" ] \
    && ! xcode-select -p 2>/dev/null | grep -q "Xcode" \
    && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
    export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

swift test
SOFTPLAN_NO_INSTALL=1 ./scripts/make-app.sh release

rm -rf "$OUT"
mkdir -p "$OUT"
# ditto, not zip: it keeps the code signature and bundle metadata intact.
ditto -c -k --sequesterRsrc --keepParent "dist.noindex/Softplan.app" "$OUT/$ZIP_NAME"
(cd "$OUT" && shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256")

# The CHANGELOG section for this version, without its heading.
NOTES="$OUT/notes.md"
awk -v heading="## [$VERSION]" '
    index($0, heading) == 1 { found = 1; next }
    found && /^## \[/        { exit }
    found                    { print }
' CHANGELOG.md | sed -e '/./,$!d' > "$NOTES"

# --- Tag and publish ---

git tag --annotate "$TAG" --file "$NOTES"
git push --quiet origin main
git push --quiet origin "$TAG"
echo "pushed main and $TAG"

REPO="$(git remote get-url origin | sed -E 's#^(git@github\.com:|https://github\.com/)##; s#\.git$##')"

if command -v gh > /dev/null && gh auth status > /dev/null 2>&1; then
    gh release create "$TAG" "$OUT/$ZIP_NAME" "$OUT/$ZIP_NAME.sha256" \
        --title "Softplan $VERSION" \
        --notes-file "$NOTES" \
        --verify-tag
    echo "published https://github.com/$REPO/releases/tag/$TAG"
else
    cat <<EOF

The tag is pushed; the GitHub Release itself still needs publishing.
Open:
  https://github.com/$REPO/releases/new?tag=$TAG&title=Softplan%20$VERSION
then paste the notes from $OUT/notes.md, attach these two files, and publish:
  $ROOT/$OUT/$ZIP_NAME
  $ROOT/$OUT/$ZIP_NAME.sha256

(With the GitHub CLI signed in, this step happens automatically:
 brew install gh && gh auth login)
EOF
fi
