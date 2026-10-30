#!/usr/bin/env bash
# Build, record and publish one release of cc/main. See cc/README.md.
# Usage: cc/release.sh            (tag v<upstream version>-cc.<next n>)
#        cc/release.sh --dry-run  (build and print the notes; no commit, tag or upload)
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
DRY=0; [ "${1:-}" = --dry-run ] && DRY=1

CERT=6aa54312eed97d2571470b692faf43fb43998cae969de984f9cc2d3672e6bbea
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 17+ 2>/dev/null || /usr/libexec/java_home)}"
BT=$(ls -d "$ANDROID_HOME"/build-tools/* | sort -V | tail -1)
APK=launcher/app/build/outputs/apk/release/app-release.apk

[ "$(git branch --show-current)" = cc/main ] || { echo "switch to cc/main first" >&2; exit 1; }
[ "$(git config user.email)" = 15225375+coherent-cache@users.noreply.github.com ] \
  || { echo "git user.email is $(git config user.email), not coherent-cache's no-reply address" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean" >&2; exit 1; }
git fetch -q upstream

base=$(git merge-base HEAD upstream/main)
upver=$(git describe --tags --abbrev=0 "$base")
n=$(( $(git tag -l "$upver-cc.*" | wc -l) + 1 ))
tag="$upver-cc.$n"
prev=$(git tag -l 'v*-cc.*' --sort=-creatordate | head -1)
src=$(git rev-parse --short HEAD)

echo "== building $tag from $src"
(cd launcher && ./gradlew -q --console=plain clean assembleRelease 2>&1 | grep -vE 'SDK XML|deprecat|Recompile' || true)
[ -f "$APK" ] || { echo "no APK built" >&2; exit 1; }

signer=$("$BT/apksigner" verify --print-certs "$APK" | sed -n 's/.*SHA-256 digest: //p' | head -1)
[ "$signer" = "$CERT" ] || { echo "signer $signer is not the fork's key $CERT" >&2; exit 1; }
sha=$(shasum -a 256 "$APK" | awk '{print $1}')
perms=$("$BT/aapt2" dump badging "$APK" | sed -n "s/^uses-permission: name='\([^']*\)'.*/\1/p" | sort)
version=$("$BT/aapt2" dump badging "$APK" | sed -n "s/^package: .*versionName='\([^']*\)'.*/\1/p")

notes=cc/releases/$tag.md
mkdir -p cc/releases
{
  echo "# $tag"
  echo
  echo "Launcher versionName $version. Built from \`$src\` on $(date +%F)."
  echo
  echo "## Upstream base"
  echo
  echo "Gathin23/cleanyourtv \`$(git rev-parse --short "$base")\` ($(git describe --tags "$base"))."
  echo
  echo "## Our patches"
  echo
  git log --format='- `%h` %s' "$base..HEAD"
  echo
  echo "## Upstream changes since the previous release"
  echo
  if [ -n "$prev" ]; then
    pbase=$(git merge-base "$prev" upstream/main)
    echo "From \`$(git rev-parse --short "$pbase")\` ($prev). Commits touching launcher/:"
    echo
    git log --format='- `%h` %s' --no-merges "$pbase..$base" -- launcher/ || true
  else
    echo "First release of this fork."
  fi
  echo
  echo "## Permissions"
  echo
  echo "$perms" | sed 's/^/- `/; s/$/`/'
  if [ -n "$prev" ] && [ -f "cc/releases/$prev.md" ]; then
    echo
    echo "Change against $prev:"
    echo
    diff <(sed -n 's/^- `\([a-zA-Z_.]*permission[^`]*\)`$/\1/p' "cc/releases/$prev.md") <(echo "$perms") \
      | sed -n 's/^< /- removed `/p; s/^> /- added `/p' | sed 's/$/`/' | grep . || echo "none"
  fi
  echo
  echo "## Artifact"
  echo
  echo "- APK SHA-256 \`$sha\`"
  echo "- Signer certificate SHA-256 \`$signer\`"
} > "$notes"

cat "$notes"
if [ "$DRY" = 1 ]; then rm -f "$notes"; echo; echo "(dry run: nothing committed)"; exit 0; fi

git add "$notes"
git commit -q -m "cc: release notes for $tag"
git tag -a "$tag" -m "$tag"
git push -q --force-with-lease origin cc/main
git push -q origin "$tag"
cp "$APK" "/tmp/cleanyourtv-$tag.apk"
gh release create "$tag" "/tmp/cleanyourtv-$tag.apk" --repo coherent-cache/cleanyourtv \
  --target cc/main --title "$tag" --notes-file "$notes"
echo "released $tag"
