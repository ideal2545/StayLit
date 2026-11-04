# StayLit

StayLit is a small menu bar utility for macOS *(version 12 and newer)* that keeps your Mac from going to sleep. It can stay on for a set duration, until a time of day, or for as long as it's switched on.

## Installation

StayLit has no published releases yet. Build it from source with Xcode 27.2 (the build command is in [FORK-NOTES.md](FORK-NOTES.md)), then copy `StayLit.app` to `/Applications`.

## How does it work?

StayLit is a small wrapper around Apple's `caffeinate` command line utility, which ships with every current version of macOS. It can also be controlled with `staylit://` URLs (see [Automation](Documentation/Automation.md)).

### Keyboard shortcut

Set a shortcut in *Settings > General* to turn StayLit on or off from any app. It needs ⌘, ⌥ or ⌃, unless it's a function key (F1–F20). Press Delete while recording to remove it.

### Does it work on a MacBook with a closed lid?

Yes, with an opt-in setting: *Settings > Advanced > Keep awake when the lid is closed*. On its own, `caffeinate` can't stop the sleep that happens when you close the lid. With this setting on, StayLit turns on the macOS `disablesleep` power setting while it's active, and turns it off again when it stops.

- **One-time setup:** StayLit saves a small helper script into its scripts folder and asks for your administrator password once. That adds a rule (`/etc/sudoers.d/staylit`) that allows exactly `pmset -a disablesleep 1` and `pmset -a disablesleep 0`, nothing else.
- **Your own setting is respected:** if you already turned `disablesleep` on yourself, StayLit leaves it on and never turns it off.
- **Heat warning:** don't keep a closed MacBook in a bag or other closed space while StayLit is active. It can get hot, and the battery drains faster. StayLit's battery settings still end the activation.
- **To remove it:** turn the setting off, then delete `~/Library/Application Scripts/com.principia29.StayLit/staylit-lid-helper.sh` and `/etc/sudoers.d/staylit`.

## Is this dangerous?

StayLit won't harm your Mac, because it relies on an official command line tool from Apple. There is no warranty, though, so use it **at your own risk**.

## Contributing

See the [Contribution Guidelines](./CONTRIBUTING.md).

## Credits and License

StayLit is based on [KeepingYouAwake](https://github.com/newmarcel/KeepingYouAwake) by Marcel Dierkes. It is released under the [MIT license](LICENSE), and the original copyright notice is kept.
