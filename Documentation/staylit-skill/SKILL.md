---
name: staylit
description: Keep this Mac awake or let it sleep with StayLit, and make sure it stays awake with the lid closed. Use when the user asks to keep the Mac awake, turn StayLit on or off, check whether StayLit is on, or says they're about to close their laptop lid and want work to keep running.
---

# StayLit

StayLit is a menu bar app that keeps the Mac awake. Control it with the `staylit` command. If `staylit` isn't found, try `/Applications/StayLit.app/Contents/Resources/staylit`.

Always pass `--json` and read the result instead of guessing.

## Commands

| Goal | Command |
| --- | --- |
| Current state | `staylit --json status` |
| Make sure it's on (leave an existing activation as it is) | `staylit --json on` |
| On for a duration | `staylit --json on --for 2h` (`90s`, `45m`, `1h30m`) |
| On until a time | `staylit --json on --until 17:00` or `--until 2026-10-03T17:00` |
| On until turned off | `staylit --json on --indefinitely` |
| Off | `staylit --json off` |
| Ready for the lid to close? | `staylit --json check lid --for 2h` |
| Lid-closed mode on / off | `staylit --json lid on` / `lid off` |

Every command waits until StayLit confirms, so there's no need to poll afterwards. Repeating a command is harmless.

## Exit codes

- `0`: done, or the check passed
- `1`: the state wasn't reached, or the check failed
- `2`: usage error
- `3`: StayLit isn't installed or couldn't start
- `4`: StayLit didn't confirm in time
- `5`: not set up. Run `staylit install` once, then retry.

## "I'm closing my laptop, make sure StayLit is ready"

1. Run `staylit --json on --for <how long they need>`, or `--indefinitely` if they didn't say.
2. Run `staylit --json check lid --for <same duration>`.
3. For each check with `"status": "fail"`, apply its `fix`, then run `check lid` again. Report any `warn` items, such as being on battery.
4. Tell the user it's ready only when `readyForLidClose` is `true`.

Notes:
- `staylit lid on` opens a confirmation on screen, and the first time it asks for an administrator password. Tell the user to look at the screen. Don't try to get around it.
- If `pauseWhileScreenLocked` fails, the user has to turn off *Settings > Advanced > Pause while the screen is locked* in StayLit. There's no command for it.
- If sleep is already disabled system-wide (the `lidClosedMode` check is `warn`), the Mac stays awake with the lid closed anyway.
- No app can keep a Mac running after it's shut down. This is only for closing the lid.

## Rules

- Never kill `caffeinate` processes or other keep-awake apps. `staylit off` only stops StayLit's own `caffeinate`.
- Don't change `pmset` settings yourself. Use `staylit lid on|off`.
- Don't turn StayLit off unless the user asked for it.
