# Building and releasing Caffeine

A shell wrapper around `xcodebuild`, `codesign`, `hdiutil`, `notarytool`,
`stapler` and `gh`. Every project-specific value lives in `.env`, which is
gitignored; the scripts themselves name no project.

```
.env ──▶ build-config.sh ──▶ build.sh          (build / sign / dmg / notarize)
                │          └▶ release-github.sh (tag + GitHub release)
                └───────────  Makefile          (aliases for build.sh)
```

## Quick start

```sh
cp .env.example .env        # then fill in NOTARIZATION_KEYCHAIN_PROFILE
./build.sh release          # universal Release build into ./build/Release
./build.sh verify           # architectures, signature, bundle id, version
./build.sh package          # clean → release → sign → dmg → notarize → staple
./release-github.sh         # tag, create the release, print the cask SHA256
```

`make <target>` calls `./build.sh <target>` for every command above.

## First-time setup

| Step | Command |
| --- | --- |
| Developer ID certificate | `security find-identity -v -p codesigning` must list *Developer ID Application* |
| Notarization credentials | `xcrun notarytool store-credentials <PROFILE> --apple-id <APPLE_ID> --team-id 7DLRYPB8WK`, then put `<PROFILE>` in `.env` |
| SwiftPM package resolution | `git config --global safe.bareRepository all` — `explicit` breaks SwiftPM's bare caches and no build can resolve Sparkle |

## Things specific to this project

**The Xcode project is not at the repo root.** `PROJECT_NAME=src/Caffeine`
carries the path prefix; every call site is `-project "${PROJECT_NAME}.xcodeproj"`,
so no script change is needed.

**The version is not in `Info.plist`.** The target builds with
`GENERATE_INFOPLIST_FILE = YES`, so `MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION` are the single source of truth and Xcode injects them
at build time. `get_version` therefore reads the *built* app's resolved
`Info.plist`, falling back to the source one. Consequence: **run `./build.sh
release` before `./release-github.sh`**, or the tag and DMG name fall back to
`0.0.1`.

To bump the version, edit *Marketing Version* in Xcode's Build Settings pane for
the Caffeine target. Use that pane rather than General ▸ Identity ▸ Version —
the latter appears to reject the `+` in `1.6.4+grazij.N`.

**Sparkle ships ad-hoc-signed nested code.** `Sparkle.framework` contains
`Autoupdate`, `Updater.app`, `Downloader.xpc` and `Installer.xpc`, all signed
ad-hoc by the vendor. `codesign` seals a bundle by hashing what is inside it, so
each must carry its final signature *before* the enclosing bundle is signed —
otherwise notarization rejects every one of them. `NESTED_CODE_PATHS` in `.env`
lists them innermost-first and `sign_nested_code` walks that list. **The order is
load-bearing.** `--deep` is not the fix; Apple documents it as unsuitable for
distribution.

If Sparkle is ever dropped, `NESTED_CODE_PATHS` collapses to
`DZFoundation.framework` alone.

## Verification gates

| Gate | Command | Pass |
| --- | --- | --- |
| Universal binary | `./build.sh verify` | `✓ arm64`, `✓ x86_64` |
| Frameworks embedded | `ls build/Release/Caffeine.app/Contents/Frameworks/` | `Sparkle.framework`, `DZFoundation.framework` |
| Nested code signed | `codesign -dvv build/Release/Caffeine.app/Contents/Frameworks/Sparkle.framework/Versions/B/Autoupdate` | `Authority=Developer ID Application`, no `adhoc` in `flags` |
| Deep signature | `codesign --verify --deep --strict --verbose=2 build/Release/Caffeine.app` | `valid on disk`, `satisfies its Designated Requirement` |
| Notarized | `xcrun stapler validate build/Caffeine-*.dmg` | `The validate action worked!` |
| Gatekeeper | `spctl -a -vv -t install build/Caffeine-*.dmg` | `accepted`, `source=Notarized Developer ID` |

A rejection is read with `xcrun notarytool log <submission-id> --keychain-profile <PROFILE>`.

## Homebrew

`release-github.sh` prints the SHA256 for the cask named by `HOMEBREW_CASK`.
The cask lives in the separate `grazij/homebrew-tap` repository as
`Casks/grazij-caffeine.rb`; both `caffeine` and `domzilla-caffeine` are already
taken in homebrew-cask.

Homebrew is the only thing that upgrades this app — Sparkle is linked but never
started — so the cask sets `auto_updates false`. `true` would make `brew upgrade`
skip the cask unless `--greedy` were passed.

```sh
brew audit --cask --strict --online grazij/tap/grazij-caffeine
brew install --cask grazij/tap/grazij-caffeine
```
