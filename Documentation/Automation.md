# StayLit Automation

## URL Scheme

StayLit supports the `staylit:///` URL scheme, so other apps and scripts can switch it on and off.

The older `keepingyouawake:///` scheme also works, with the same commands.

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

## Command Line Usage

The URL scheme can be used together with the `open` command to control StayLit from the command line.

```
open -g "staylit:///activate"
open -g "staylit:///activate?seconds=30"
open -g "staylit:///deactivate"
open -g "staylit:///toggle"
```
