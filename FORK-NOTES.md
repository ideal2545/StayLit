# Fork Notes

This is a fork of [newmarcel/KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) (MIT, © Marcel Dierkes). It keeps the app building with **Xcode 27.2** and running on **macOS 27**, and carries fixes and community pull requests that were still open upstream as of November 2026.

These changes aren't meant for upstream, so please don't send them to KeepingYouAwake as pull requests.

## What differs from upstream `main`

### macOS 27 / Xcode 27.2
- Upstream `main` already raised the deployment target to macOS 12 for Xcode 27. The project builds cleanly with Xcode 27.2 / the macOS 27 SDK and produces a universal (arm64 + x86_64) binary.
- Replaced one deprecated `NSStatusItem.image` read with `button.image`. Two deprecation warnings remain on purpose (`highlightMode`, `popUpStatusItemMenu:`). Their replacements change click/highlight behavior and need hands-on testing.

### Bug fixes
| Upstream issue | Fix |
|---|---|
| [#157](https://github.com/newmarcel/KeepingYouAwake/issues/157) Remaining duration went negative after sleep | `caffeinate -t` does not count time spent asleep. The fire date is now enforced by a wall-clock timer and re-checked on wake, and the label never shows negative time. |
| [#248](https://github.com/newmarcel/KeepingYouAwake/issues/248) `activate` URL toggling when already on | A deactivation callback from the previous activation ran *after* the new activation and flipped the UI and power monitoring off. Stale callbacks are now dropped. |
| (no issue) Display-sleep setting needed reactivation | Changing "Allow the display to sleep" now restarts `caffeinate` with the remaining time, so it applies immediately. |

`KYASleepWakeTimer` also got smaller hardening fixes:
- `caffeinate` arguments are passed as separate argv entries.
- Launch errors are handled.
- Scheduling twice no longer orphans a `caffeinate` process.
- Deactivation is exactly-once.

It now has its own test target (9 tests). The whole suite is 62 tests, all passing on Xcode 27.2.

### Merged upstream pull requests
| PR | What | Notes |
|---|---|---|
| [#240](https://github.com/newmarcel/KeepingYouAwake/pull/240) | "Allow the display to sleep" toggle in the menu (closes [#265](https://github.com/newmarcel/KeepingYouAwake/issues/265)) | Combined with the fix above, toggling it during an activation takes effect right away. |
| [#241](https://github.com/newmarcel/KeepingYouAwake/pull/241) | Live-updating remaining time in the menu | Also rebuilds the menu if the activation ends while it's open. |
| [#242](https://github.com/newmarcel/KeepingYouAwake/pull/242) | Clamp battery threshold to 10–100% | |
| [#245](https://github.com/newmarcel/KeepingYouAwake/pull/245) | Missing Korean translations | |
| [#261](https://github.com/newmarcel/KeepingYouAwake/pull/261) | Makefile version → 1.6.9 | Only the Makefile change. Its README claims about Intel support were not verified, so they were not taken. |
| [#263](https://github.com/newmarcel/KeepingYouAwake/pull/263) | "Activate until a time of day" (closes [#161](https://github.com/newmarcel/KeepingYouAwake/issues/161)) | Merged after a review pass that fixed: clock-time resume rolling over to the next day, invalid or past `until=` URLs deactivating a running activation, non-existent dates (Feb 30, DST gaps) being silently normalized, deleted presets coming back when only clock times are configured, and a DST-fragile test. |

Original authorship is preserved via merge commits.

### Not done (feature requests, left for later)
Lid-closed modes (#255, #258, #262, #266), CLI status (#225), notification toggles (#172), schedules (#189), keyboard shortcut (#190), and deactivating on lock/sleep (#93, #98, #108) are all new features, not compatibility work. #235 (activate on *window* mirroring / AirPlay) needs hardware to reproduce.

## Fork-specific setup
- **Sparkle updates** point at `https://ideal2545.github.io/StayLit/appcast.xml`. That URL doesn't exist yet, so update checks fail quietly instead of offering upstream builds that would overwrite this fork. Shipping updates later needs GitHub Pages plus an appcast, and builds signed with the same Developer ID each time. Sparkle can also use an EdDSA key (`generate_keys`); upstream never set one.
- **Signing:** the project still contains upstream's `DEVELOPMENT_TEAM`. Override it on the command line rather than committing your own team ID:
  ```sh
  xcodebuild -workspace KeepingYouAwake.xcworkspace -scheme "KeepingYouAwake (Direct)" \
    -configuration Release -derivedDataPath build -destination 'platform=macOS' \
    DEVELOPMENT_TEAM=<your team> CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" \
    PROVISIONING_PROFILE_SPECIFIER=""
  ```
  An *Apple Development* signature runs on the Mac that built it. Giving the app to others needs a Developer ID certificate and notarization.
- **Tests:** `make test` needs `xcbeautify` (`brew install xcbeautify`), or run `xcodebuild test -workspace KeepingYouAwake.xcworkspace -scheme KeepingYouAwake -destination 'platform=macOS'` directly.

## Name and bundle identifier
The app still uses the name *KeepingYouAwake* and the bundle ID `info.marcel-dierkes.KeepingYouAwake`. With the same bundle ID, your existing settings carry over, and the app replaces the upstream app in place.

Trade-offs if you want to rename later:
- **Keep the current ID (status quo):** settings and custom icons carry over. macOS may ask once whether "KeepingYouAwake" may access data from other apps, because the sandbox container was created by Marcel's signature. Choose Allow. Homebrew's `keepingyouawake` cask, if you use it, would overwrite the fork.
- **New name + new bundle ID** (e.g. `com.<you>.<NewName>` in `Configuration.xcconfig`, plus the launcher's ID in the project): clean container, no prompt, and it can run next to the original. Settings start fresh. The MIT license allows renaming and redistribution as long as `LICENSE` and the copyright notice stay. A different name also avoids confusion with the original app, which is polite if you publish builds.
