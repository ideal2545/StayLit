# StayLit

**Keep your Mac awake, from the menu bar.** Click the icon and your Mac stays awake: for an hour, until 5 PM, or until you click again. It can even stay awake with the lid closed.

StayLit runs on macOS 12 and newer and is built for macOS 27. It's a fork of [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) with new features, fixes and community pull requests merged.

## Features

- **One click:** click the menu bar icon to turn StayLit on or off. The icon shows a sunrise: outlined when off, with rays when on.
- **Durations or a time of day:** keep the Mac awake for a set time, *until 5:00 PM*, until a one-off date and time, or indefinitely. Right-click (or ⌥-click / ⌃-click) the icon for the menu.
- **Keep awake with the lid closed:** an opt-in mode for closed-lid work, even without an external display (see [below](#keep-awake-with-the-lid-closed)).
- **Keyboard shortcut:** turn StayLit on or off from any app.
- **Battery aware:** turns off below a battery level you choose, or when Low Power Mode turns on.
- **Smart pauses:** optionally pauses while the screen is locked or while another user is logged in, and resumes where it left off. It can also turn off when you put the Mac to sleep.
- **Automation:** control it from scripts, Shortcuts or Terminal with `staylit://` links.
- **Quiet notifications:** optionally only tells you when StayLit turns on or off by itself, not when you clicked it.
- **Display sleep:** let the display sleep while the Mac stays awake, from the menu or in Settings.
- **More options:** turns on when an external display is connected, starts at login, activates on launch, quits when the timer ends, and supports custom menu bar icons.

## Installation

StayLit has no published releases yet, so build it from source with Xcode 27.2, signing with your own team ID:

```sh
xcodebuild -workspace StayLit.xcworkspace -scheme "StayLit (Direct)" \
  -configuration Release -derivedDataPath build -destination 'platform=macOS' \
  DEVELOPMENT_TEAM=<your team> CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="Apple Development" \
  PROVISIONING_PROFILE_SPECIFIER=""
```

Then copy `build/Build/Products/Release/StayLit.app` to `/Applications`. An *Apple Development* signature only runs on the Mac that built it.

### Coming from KeepingYouAwake?

StayLit has its own bundle ID (`com.principia29.StayLit`), so it can run next to KeepingYouAwake while you switch:

1. Turn off *Start at Login* in KeepingYouAwake, then quit and delete it.
2. Turn on *Start at Login* in StayLit.
3. Change any scripts from `keepingyouawake://` to `staylit://`. StayLit doesn't answer the old links, so they keep going to KeepingYouAwake until you change them.
4. Settings start fresh. To keep custom icons, copy them over (see [Custom Icons](Documentation/Custom%20Icons.md)).

## Usage

| To… | Do this |
| --- | --- |
| Turn StayLit on or off | Click the menu bar icon, or press your shortcut |
| Pick a duration or *Until…* | Right-click the icon, then *Activate for Duration* |
| Change the default duration | *Settings > Activation Duration*, then *Set Default* |
| Add a time of day, like *Until 5:00 PM* | *Settings > Activation Duration > +*, then switch to *Until* |
| Set a keyboard shortcut | *Settings > General > Keyboard Shortcut*. It needs ⌘, ⌥ or ⌃, unless it's a function key. Delete removes it. |
| Set the battery cutoff | *Settings > Battery* |
| Pause when locked, lid-closed mode and more | *Settings > Advanced* |

## Keep awake with the lid closed

Normally a MacBook sleeps when you close the lid, unless it's on power with an external display. Turn on *Settings > Advanced > Keep awake when the lid is closed*, and StayLit keeps it awake with the lid closed whenever StayLit is on, on battery too.

- **How:** StayLit turns on the macOS `disablesleep` power setting while it's on, and turns it off again when it stops.
- **One-time setup:** StayLit saves a small helper script into its scripts folder and asks for your administrator password once. That adds a rule (`/etc/sudoers.d/staylit`) allowing exactly `pmset -a disablesleep 1` and `pmset -a disablesleep 0`, nothing else.
- **Your own setting wins:** if `disablesleep` is already on when StayLit starts, StayLit leaves it on and never turns it off.
- **It tells you when it isn't sure:** if something else turns `disablesleep` off while StayLit is on, StayLit says so instead of fighting it. When StayLit turns sleep back on, the notification has a *Leave Sleep Disabled* button, in case you wanted it off.
- **Crash-safe:** if StayLit quits unexpectedly with sleep disabled, it turns sleep back on at its next launch and tells you.
- **Battery settings still apply,** so a closed Mac on battery still stops at your cutoff. A closed laptop in a bag can get warm.
- **To remove it:** turn the setting off, then delete `~/Library/Application Scripts/com.principia29.StayLit/staylit-lid-helper.sh` and `/etc/sudoers.d/staylit`.

## Automation

StayLit answers `staylit://` links, so anything that can open a URL can control it:

```sh
open -g "staylit:///activate"                 # default duration
open -g "staylit:///activate?minutes=45"
open -g "staylit:///activate?until=17:00"
open -g "staylit:///deactivate"
open -g "staylit:///toggle"
```

All commands are in [Automation](Documentation/Automation.md).

## How it works

StayLit runs Apple's `caffeinate` tool while it's on, and stops only its own `caffeinate` when it turns off. A `caffeinate` you started yourself, or another app's, keeps running. The only system setting StayLit ever changes is `disablesleep`, and only in lid-closed mode.

## Contributing

See the [Contribution Guidelines](./CONTRIBUTING.md) and the [Changelog](CHANGELOG.md).

## Credits and License

StayLit is based on [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) by Marcel Dierkes, and includes pull requests from its contributors (see the [Changelog](CHANGELOG.md)). It's released under the [MIT license](LICENSE), and the original copyright notice is kept.
