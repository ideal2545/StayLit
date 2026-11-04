# StayLit Automation

## URL Scheme

StayLit supports the `staylit:///` URL scheme, so other apps and scripts can switch it on and off.

StayLit doesn't answer `keepingyouawake:///` links, so it never clashes with KeepingYouAwake installed on the same Mac. Scripts written for KeepingYouAwake work after changing the scheme to `staylit:///`.

### activate

```
staylit:///activate
```

Activates and prevents sleep for the configured default duration.

#### activate?seconds=X

```
staylit:///activate?seconds=30
```

Activates and prevents sleep for exactly 30 seconds.

#### activate?minutes=X

```
staylit:///activate?minutes=5
```

Activates and prevents sleep for exactly 5 minutes.

#### activate?hours=X

```
staylit:///activate?hours=2
```

Activates and prevents sleep for exactly 2 hours.

#### activate?until=HH:MM

```
staylit:///activate?until=17:00
```

Activates and prevents sleep until the next 5:00 PM local time. The time uses the 24-hour clock; if it has already passed today, the timer runs until that time tomorrow.

#### activate?until=YYYY-MM-DDTHH:MM

```
staylit:///activate?until=2026-10-03T17:00
```

Activates and prevents sleep until that local date and time. A date in the past, a date that does not exist (e.g. `2027-02-30T17:00`) or a time skipped by a daylight saving change is ignored, and a running activation stays as it is. The same applies to an invalid `until=HH:MM` value.

_Please note: the seconds, minutes, hours and until parameters cannot be combined at the moment._

### deactivate

```
staylit:///deactivate
```

Deactivates and allows the system to go to sleep.

### toggle

```
staylit:///toggle
```

Toggles the activation state between activated and deactivated.

### lid-closed?enabled=1

```
staylit:///lid-closed?enabled=1
staylit:///lid-closed?enabled=0
```

Turns *Keep awake when the lid is closed* on or off. Turning it on always goes through the setup, which asks you to confirm on screen (and, the first time, for your administrator password), so a link can't turn it on silently.

### status

```
staylit:///status
```

Asks StayLit to write its status file now (see [the `staylit` command](#the-staylit-command)). It changes nothing.

## The `staylit` command

StayLit includes a command line tool, made to be easy for scripts and AI agents to use. Set it up once:

```sh
/Applications/StayLit.app/Contents/Resources/staylit install
```

This puts a small status-writer script in StayLit's scripts folder and links `staylit` into `/usr/local/bin` (or `~/.local/bin`; pick another folder with `--bin`). The sandbox hides StayLit's own folders from other apps, so StayLit runs that script to save its state in `~/Library/Application Support/StayLit/status.json`, where the command can read it. `staylit uninstall` removes both.

| Command | What it does |
| --- | --- |
| `staylit status` | Whether StayLit is on, until when, and whether lid-closed mode is on |
| `staylit on` | Makes sure StayLit is on. If it's already on, it's left as it is. |
| `staylit on --for 2h` | On for a duration: `90s`, `45m`, `2h`, `1h30m`, or a number of minutes |
| `staylit on --until 17:00` | On until a time, or a date and time such as `2026-10-03T17:00` |
| `staylit on --indefinitely` | On until turned off |
| `staylit off` | Makes sure StayLit is off |
| `staylit lid on` / `lid off` | Turns lid-closed mode on (with the on-screen setup) or off |
| `staylit check lid [--for 2h]` | Checks that the Mac will stay awake with the lid closed, and lists what to fix |

- **It confirms:** every command waits until StayLit reports the new state, then prints it.
- **`--json`:** add it to any command to get one JSON object, with `ok` and a `state` object (`check lid` also has `checks`, each with `name`, `status` of `ok`, `warn` or `fail`, `detail` and `fix`).
- **Exit codes:** `0` done or ready, `1` not reached or a check failed, `2` usage error, `3` StayLit not found or couldn't start, `4` StayLit didn't confirm in time, `5` not set up yet (run `staylit install`).
- **It finds the app** it was installed from. Set `STAYLIT_APP` to use another copy.
- **Only its own `caffeinate`:** turning StayLit off stops StayLit's `caffeinate` and nothing else.

`check lid` looks at the live system, not only StayLit's settings. It checks that StayLit is on and stays on long enough, lid-closed mode and its helper, the `disablesleep` setting, *Pause while the screen is locked* (closing the lid usually locks the screen, which would pause StayLit), and the battery and Low Power Mode.

## Using `open`

The URL scheme also works with the `open` command.

```
open -g "staylit:///activate"
open -g "staylit:///activate?seconds=30"
open -g "staylit:///deactivate"
open -g "staylit:///toggle"
```
