# coherent-cache/cleanyourtv: the Acer R4 build

This fork builds the CleanYourTV launcher for one TV model: the Acer R4
(SCBC R4, Realtek rtd2851m, Android TV 14, build `UKR1.260308`). Every release is upstream at a
named commit plus the patches listed below, nothing else.

Commits, tags and releases here use only the coherent-cache identity: the clone sets a repo-local
`user.email` of `15225375+coherent-cache@users.noreply.github.com`. Check it before committing
(`git config user.email`), since a global git identity would otherwise apply.

## Branches and remotes

| Name | What it holds |
|---|---|
| `main` | A mirror of `upstream/main` ([Gathin23/cleanyourtv](https://github.com/Gathin23/cleanyourtv)). Never committed to directly. |
| `cc/main` | `upstream/main` + our patches, rebased on each sync. Default branch of the fork. Releases are tagged here. |
| remote `upstream` | Gathin23/cleanyourtv |
| remote `gwiersma` | gwiersma/cleanyourtv, source of the Continue watching patch |

`git log --oneline upstream/main..cc/main` lists every patch we carry, at any time.

## Patches we carry

| Patch | Why | Upstream status |
|---|---|---|
| launcher: Continue watching row from the system's Watch Next table | Cherry-picked from gwiersma `d723b1f9`. Watch Next row with no INTERNET permission. | Upstream declined a similar PR (#2416) to keep the launcher small. |
| cc: Continue watching on, R4 config | `continue_watching` is a build setting, so it is flipped in `config.xml`. `cc/themes/acer-r4/config.json` holds the dock (two levels deep on purpose: upstream's `test_manage_set` guards every `*/*/config.json`). | Fork-only. |
| cc: fork tooling | This folder. | Fork-only. |

Keep patches small and one concern each. A patch that upstream accepts is dropped here at the next sync.

## Signing

Upstream signs release builds with the build machine's Android debug key. This fork keeps that, so it
carries no build patch. The key is `~/.android/debug.keystore` on the build machine, backed up at
`~/.config/tv-launchers/cleanyourtv-signing.keystore` (600).

Signer certificate SHA-256, checked by `release.sh` and `install.sh`:
`6aa54312eed97d2571470b692faf43fb43998cae969de984f9cc2d3672e6bbea`

A different key means Android refuses the update, and the only way on is uninstalling the launcher
(the TV loses its launcher settings). If the key is ever lost, restore it from the backup first.

## Routine

1. `cc/sync.sh` fetches upstream, lists what is new (commits, launcher diffstat, manifest and
   permission changes), mirrors `main`, rebases `cc/main`, runs the test suite. Read its output
   before going on. It does not push `cc/main`; `git push --force-with-lease origin cc/main` does,
   after review.
2. `cc/release.sh` builds from a clean `cc/main`, checks the signer, writes
   `cc/releases/<tag>.md` (upstream base, our patches, upstream changes since the last release,
   permissions and their diff, APK and cert SHA-256), commits it, tags `v<upstream>-cc.<n>`, and
   publishes a GitHub release with the APK.
3. `cc/install.sh <tag|apk>` installs on the TV, checks the signer, grants `READ_TV_LISTINGS`,
   keeps the launcher as HOME. `--theme` also pushes `cc/themes/acer-r4/config.json`, which restarts Home:
   only do that when the TV is not in use.

## Known test noise

`tests/test_bench_counts.py::RefusedBeforeTheTVTest` fails under pytest (program name differs).
Run the suite as CI does: `tools/venv/bin/python -m unittest discover -s tests`, Python 3.12.
