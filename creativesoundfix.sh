#!/bin/bash

# ==============================================================================
# Creative Audio Surgical Restarter - Automated Edition
#
# This script periodically kills only the core audio engine plugin.
# The macOS launchd service automatically restarts it almost instantly,
# providing a fast, low-disruption fix for frequent audio crackling.
# ==============================================================================

# The name of the core audio engine to be surgically restarted.
# Do not change this.
# I restart only this plugin instead of the whole audio service. A wider
# kill would drop every sound on the machine, and the crackling I get from
# the Creative device clears when this one piece comes back.
PLUGIN_PROCESS_NAME="AudioServerDriverPlugin.app"

# Optional fixed interval in seconds, set in the environment, for example:
#   RESTART_INTERVAL_SECONDS=120 ./creativesoundfix.sh
# When it is not set, the interval is randomized between 3 and 5 minutes
# (180 to 300 seconds) on every cycle, as described in the README.
# I copy the environment value into a second name on purpose. The loop
# below reuses RESTART_INTERVAL_SECONDS as its per cycle working value,
# so testing that name inside the loop would test a value the loop itself
# had already overwritten. FIXED_INTERVAL_SECONDS is the copy that stays
# true for the whole run.
FIXED_INTERVAL_SECONDS="${RESTART_INTERVAL_SECONDS:-}"
if [ -n "$FIXED_INTERVAL_SECONDS" ]; then
    # I check the characters before I compare the number. A value like abc
    # fed straight into the -lt test makes bash print its own error and the
    # test fails for the wrong reason, so the digit check has to run first.
    case "$FIXED_INTERVAL_SECONDS" in
        *[!0-9]*)
            echo "Error: RESTART_INTERVAL_SECONDS must be a positive whole number of seconds, got '${FIXED_INTERVAL_SECONDS}'." >&2
            exit 1
            ;;
    esac
    if [ "$FIXED_INTERVAL_SECONDS" -lt 1 ]; then
        echo "Error: RESTART_INTERVAL_SECONDS must be at least 1, got '${FIXED_INTERVAL_SECONDS}'." >&2
        exit 1
    fi
fi

# --- Main Execution Loop ---

echo "--- Starting Creative Surgical Audio Restarter ---"
if [ -n "$FIXED_INTERVAL_SECONDS" ]; then
    echo "The core audio plugin will be reset every ${FIXED_INTERVAL_SECONDS} seconds."
else
    echo "The core audio plugin will be reset every 3-5 minutes (randomized)."
fi
echo "Audio interruption will be minimal."
echo "Press Control+C to stop this script."

# Loop forever. I keep no state files and install nothing, so stopping
# this with Control+C leaves nothing behind to clean up.
# The validation above runs before the banner and before this loop for a
# reason: a bad fixed interval should fail in the first second, not after
# the first sleep has already passed and a reset has already happened.
while true; do
    if [ -n "$FIXED_INTERVAL_SECONDS" ]; then
        RESTART_INTERVAL_SECONDS="$FIXED_INTERVAL_SECONDS"
    else
        # Randomize interval between 3 and 5 minutes (180 to 300 seconds)
        # I fixed this arithmetic after I caught the old form, RANDOM
        # % 241 + 60, handing out waits as low as 60 seconds while the
        # banner and the README both promised 3 to 5 minutes. % 121
        # gives 0 to 120 and the + 180 puts the floor where I said it was.
        # I randomize at all because a reset on an exact clock lands in
        # the middle of a track often enough to be its own annoyance.
        RESTART_INTERVAL_SECONDS=$((RANDOM % 121 + 180))
    fi

    echo "----------------------------------------"
    echo "Waiting for ${RESTART_INTERVAL_SECONDS} seconds until next reset..."
    sleep "$RESTART_INTERVAL_SECONDS"

    # I sleep first and kill after. Starting this script should not cut
    # the audio the moment it launches, so the first reset only comes
    # once a full interval has passed.
    echo "Performing surgical reset at $(date)..."
    # Kill the plugin. macOS launchd will restart it automatically.
    # The -f matters to me here: I match against the full command line,
    # not only the short process name. I know that also means any other
    # process with this string in its command line would match too. On
    # the single user Mac this is written for, I accept that rather than
    # guess at a process id that changes every boot.
    pkill -f "$PLUGIN_PROCESS_NAME"
    # I save the status on the very next line. One echo in between would
    # replace $? with the echo result and both branches below would lie.
    pkill_status=$?

    if [ "$pkill_status" -eq 0 ]; then
        echo "Successfully sent termination signal to '${PLUGIN_PROCESS_NAME}'."
        echo "macOS will now restart it automatically."
    else
        # I do not split pkill failures by kind here. A missing plugin is
        # the case I actually hit, so every non-zero status gets this one
        # warning and the loop keeps going. Failing hard would trade a
        # skipped reset for a dead script, and the next cycle may find
        # the plugin running again.
        echo "Warning: Process '${PLUGIN_PROCESS_NAME}' not found. It may not have been running."
    fi
done
