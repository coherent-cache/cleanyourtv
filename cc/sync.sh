#!/usr/bin/env bash
# Bring cc/main up to date with upstream, showing exactly what comes in. See cc/README.md.
# Does not push cc/main: review the output, then `git push --force-with-lease origin cc/main`.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

[ "$(git branch --show-current)" = cc/main ] || { echo "switch to cc/main first" >&2; exit 1; }
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean" >&2; exit 1; }

git fetch -q upstream
git fetch -q gwiersma 2>/dev/null || true
old_base=$(git merge-base HEAD upstream/main)
new_base=$(git rev-parse upstream/main)

if [ "$old_base" = "$new_base" ]; then
  echo "upstream/main has nothing new (at $(git describe --tags "$new_base"))"
else
  echo "== upstream: $(git describe --tags "$old_base") -> $(git describe --tags "$new_base"), $(git rev-list --count "$old_base..$new_base") commits"
  echo
  echo "== commits touching launcher/"
  git log --oneline --no-merges "$old_base..$new_base" -- launcher/ | sed 's/^/  /'
  echo
  echo "== launcher diffstat"
  git diff --stat "$old_base" "$new_base" -- launcher/ | tail -25
  echo
  echo "== manifest changes (permissions, services, receivers)"
  git diff "$old_base" "$new_base" -- launcher/app/src/main/AndroidManifest.xml \
    | grep -E '^[+-] .*(uses-permission|<service|<receiver|<provider|android:exported)' || echo "  none"
  echo
  git push -q origin "upstream/main:refs/heads/main"
  echo "mirrored upstream/main to origin/main"
  echo
  echo "== rebasing cc/main ($(git rev-list --count "$old_base..HEAD") patches) onto upstream/main"
  if ! git rebase -q upstream/main; then
    echo "rebase stopped on a conflict: resolve, git rebase --continue, then run this script again" >&2
    exit 1
  fi
fi

echo
echo "== our patches on top of upstream"
git log --oneline upstream/main..HEAD | sed 's/^/  /'
echo
echo "== tests (as upstream CI runs them)"
tools/venv/bin/python -m unittest discover -s tests 2>&1 | tail -4
