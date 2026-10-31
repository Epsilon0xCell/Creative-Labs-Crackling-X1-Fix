![Creative-Labs-Crackling-X1-Fix](banner.png)

# Creative Labs Crackling X1 Fix

My Creative Labs audio device crackles on macOS, and the fix that works
for me is restarting one piece of the audio system on a timer instead of
rebooting or replugging the device. This repo holds the small shell
script that does that, plus a masking workaround I used before the
script, written up at the end.

## How it works

- The script kills the `AudioServerDriverPlugin.app` process at a set
  interval.
- macOS starts the plugin again on its own (launchd brings it back),
  which clears the crackling on my machine without a reboot or a
  replug.
- The script keeps no state files and installs nothing.

## Usage

1. Open Terminal and go to the directory you cloned this repo into:
   ```sh
   cd Creative-Labs-Crackling-X1-Fix
   ```

2. Run the script:
   ```sh
   ./creativesoundfix.sh
   ```
   The script file carries its executable bit in git. If your copy lost
   it, restore it with `chmod +x creativesoundfix.sh`.

   The script runs until you stop it. The first reset only happens
   after one full interval has passed, so starting it does not cut the
   audio right away.

## Stopping and reversing it

Press Control+C. That is the whole undo: the script changes no settings,
writes no files, and installs no launch items, so once it stops, nothing
it did is left running. Each reset it already performed is also undone
by macOS itself when the plugin comes back.

## Configuration

- By default the interval is randomized between 3 and 5 minutes (180 to
  300 seconds) on every cycle. I randomize it because a reset on an
  exact clock lands in the middle of a track often enough to be its own
  annoyance.
- To use a fixed interval instead, set `RESTART_INTERVAL_SECONDS` in
  the environment when you run the script:
  ```sh
  RESTART_INTERVAL_SECONDS=120 ./creativesoundfix.sh
  ```
  That example resets every 120 seconds (every 2 minutes). The value
  must be a positive whole number of seconds; anything else exits with
  an error before the loop starts. Leading zeros are read as the number
  they name, so 007 is 7 seconds.

If a reset finds no matching process, the script prints a warning and
keeps going. If `pkill` itself fails, the warning says so and names the
status, instead of claiming the plugin was missing.

## Platform limits, stated plainly

- This is a macOS script. It relies on macOS restarting the plugin, and
  on a single user Mac: `pkill -f` matches any process whose command
  line contains the plugin name, which I accept on my own machine and
  would not ship to a shared one.
- I have not run this pass on a Mac. The changes in this pass (splitting
  the `pkill` warnings by status, normalizing a fixed interval typed
  with leading zeros, the executable bit) were verified on a Linux host
  with `bash -n` and with stub `sleep` and `pkill` programs that log
  their arguments, through the test suite in `test_creativesoundfix.py`
  (`python3 -m unittest`). Whether the sound comes back clean on any
  given Mac is not something those tests can show.

## Files

- `creativesoundfix.sh` - the script
- `test_creativesoundfix.py` - the test suite described above
- `banner.png`, `logo.png` - project branding
- `LICENSE` - MIT license

## The masking workaround I used first

Before the script, I masked the crackling instead of restarting
anything: play rain or fire sounds from myNoise in the background while
listening to music, and the crackling blends into the background noise.
It does not fix the device; it makes the crackling hard to pick out. I
also tried a targeted EQ approach, with the low treble, treble, and
high treble pushed up and the other frequencies turned down, for the
same reason.

```
https://mynoise.net/NoiseMachines/fireNoiseGenerator.php
https://mynoise.net/NoiseMachines/stormSoundGenerator.php

Here is the custom set which tricks your mind:
https://mynoise.net/NoiseMachines/custom.php?l=3737373737373939393900&m=FIRE7~FIRE7~FIRE7~FIRE8~FIRE8~FIRE8~FIRE9~FIRE9~FIRE9~FIRE9&orig=1&title=A%20Base%20Line

Also here is a custom set I made titled Ambience:
https://mynoise.net/NoiseMachines/custom.php?l=9969836856565845564500&m=FLOATING0~FLOATING1~FLOATING2~FLOATING3~FIRE7~FLOATING7~FIRE8~FLOATING8~FIRE9~FLOATING9&orig=1&title=Audioambience
```

## Why I did not go the detection route

An approach that listens for crackling and reacts only then sounds
better on paper than it works in music: the crackling shows up mostly
in the right earphone and looks a lot like ordinary audio spikes, so
false positives stay a problem. The remaining routes were reverse
engineering the driver, which is a much bigger job, or waiting for
Creative to fix it. Restarting the plugin on a timer is the option I
could actually finish, so it is the one in this repo.

## Disclaimer

Use at your own risk. This script is provided as-is and may not work for
all systems or configurations.
