# Fork Notes

StayLit is a fork of [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) by Marcel Dierkes (MIT, © 2014 - present Marcel Dierkes). The app and nearly all of its code are his and the KeepingYouAwake contributors'. It keeps the app building with **Xcode 27.2** and running on **macOS 27**, and carries fixes and community pull requests that were still open upstream as of November 2026.

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
| PR | Author | What | Notes |
|---|---|---|---|
| [#240](https://github.com/newmarcel/KeepingYouAwake/pull/240) | [@lucasmezencio](https://github.com/lucasmezencio) | "Allow the display to sleep" toggle in the menu (closes [#265](https://github.com/newmarcel/KeepingYouAwake/issues/265)) | Combined with the fix above, toggling it during an activation takes effect right away. |
| [#241](https://github.com/newmarcel/KeepingYouAwake/pull/241) | [@bryanvrgsc](https://github.com/bryanvrgsc) | Live-updating remaining time in the menu | Also rebuilds the menu if the activation ends while it's open. |
| [#242](https://github.com/newmarcel/KeepingYouAwake/pull/242) | [@bryanvrgsc](https://github.com/bryanvrgsc) | Clamp battery threshold to 10–100% | |
| [#245](https://github.com/newmarcel/KeepingYouAwake/pull/245) | [@wplong11](https://github.com/wplong11) | Missing Korean translations | |
| [#261](https://github.com/newmarcel/KeepingYouAwake/pull/261) | [@jincaiw](https://github.com/jincaiw) | Makefile version → 1.6.9 | Only the Makefile change. Its README claims about Intel support were not verified, so they were not taken. |
| [#263](https://github.com/newmarcel/KeepingYouAwake/pull/263) | [@austin-rt](https://github.com/austin-rt) | "Activate until a time of day" (closes [#161](https://github.com/newmarcel/KeepingYouAwake/issues/161)) | Merged after a review pass that fixed: clock-time resume rolling over to the next day, invalid or past `until=` URLs deactivating a running activation, non-existent dates (Feb 30, DST gaps) being silently normalized, deleted presets coming back when only clock times are configured, and a DST-fragile test. |

Each PR was merged with its original commits, so the authors keep authorship in the git history. They are also thanked in [CHANGELOG.md](CHANGELOG.md).

### Not done (feature requests, left for later)
Lid-closed modes (#255, #258, #262, #266), CLI status (#225), notification toggles (#172), schedules (#189), keyboard shortcut (#190), and deactivating on lock/sleep (#93, #98, #108) are all new features, not compatibility work. #235 (activate on *window* mirroring / AirPlay) needs hardware to reproduce.

## Fork-specific setup
- **Sparkle updates** point at `https://ideal2545.github.io/StayLit/appcast.xml`. That URL doesn't exist yet, so update checks fail quietly instead of offering upstream builds that would overwrite this fork. Shipping updates later needs GitHub Pages plus an appcast, and builds signed with the same Developer ID each time. Sparkle can also use an EdDSA key (`generate_keys`); upstream never set one.
- **Signing:** the project still contains upstream's `DEVELOPMENT_TEAM`. Override it on the command line rather than committing your own team ID:
  ```sh
  xcodebuild -workspace StayLit.xcworkspace -scheme "StayLit (Direct)" \
    -configuration Release -derivedDataPath build -destination 'platform=macOS' \
    DEVELOPMENT_TEAM=<your team> CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" \
    PROVISIONING_PROFILE_SPECIFIER=""
  ```
  An *Apple Development* signature runs on the Mac that built it. Giving the app to others needs a Developer ID certificate and notarization.
- **Tests:** `make test` needs `xcbeautify` (`brew install xcbeautify`), or run `xcodebuild test -workspace StayLit.xcworkspace -scheme StayLit -destination 'platform=macOS'` directly.

## Name and bundle identifier
The fork is called **StayLit**. Its bundle ID is `com.principia29.StayLit` and its launcher's is `com.principia29.StayLit.Launcher`.

Upstream's README asks that forks not be redistributed under the same name and icon. The MIT license doesn't require that, but the rename and the new icon honor it. `LICENSE`, Marcel's copyright line (`NSHumanReadableCopyright`) and the credits are kept.

**What changed in the rename**
- **Icon:** StayLit has its own app icon (a star rising over a planet, with warp streaks) and menu bar icon (a sunrise: outlined when off, with rays when on). The app icon is an Icon Composer document in `StayLit/AppIcon.icon` and `KYALauncher/AppIcon.icon`, built from plain SVG layers. The menu bar icons are the `ActiveIcon`/`InactiveIcon` template PNGs at 22×20 pt. The scripts in `Tools/Icons/` regenerate both. Custom menu bar icons still work as before.
- Bundle IDs live in `Configuration.xcconfig` and in the launcher target in the project file. The legacy login-item code in `NSApplication+KYALaunchAtLogin.m` has the launcher ID too. These three must match.
- `PRODUCT_NAME` is `StayLit` / `StayLit Launcher`. The Xcode project, workspace, targets, schemes and source folders are named StayLit too (`StayLit.xcworkspace`, schemes `StayLit` and `StayLit (Direct)`, sources in `StayLit/`, translations in `Localizations/StayLit/`). Upstream changes still merge, because git follows the renamed paths; edits to `project.pbxproj` may need a hand.
- Source files that came from KeepingYouAwake keep their original `// KeepingYouAwake` headers (see CONTRIBUTING).
- Visible strings changed: the Settings window title (all languages), the About window and the credits.
- URL schemes: `staylit://` is new. `keepingyouawake://` still works.
- `Makefile`: `NAME` is the project and scheme name and `APP_NAME` names the `dist/` output. Both are `StayLit`.

**Left unchanged on purpose**
- **User defaults keys** keep their `info.marcel-dierkes.KeepingYouAwake.*` prefix. They are internal, they live in StayLit's own sandbox container, and xib bindings refer to them. Renaming them means changing every one at once, in the code and in the xibs.
- **Sparkle feed URLs** follow the GitHub repo name, which is now `ideal2545/StayLit` (`ideal2545.github.io/StayLit/...`). If the repo is renamed again, update `KYAAppUpdater.m` too.

**Effects of the new bundle ID**
- StayLit gets its own sandbox container, so settings start fresh, and the "access data from other apps" prompt goes away.
- It can run next to the original KeepingYouAwake. Both claim the `keepingyouawake://` scheme, so remove the original once you've switched.
- When switching, turn off *Start at Login* in the old app *before* deleting it, then turn it on in StayLit.
