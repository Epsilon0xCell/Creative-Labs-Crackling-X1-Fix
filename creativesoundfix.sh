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
PLUGIN_PROCESS_NAME="AudioServerDriverPlugin.app"

# Optional fixed interval in seconds, set in the environment, for example:
#   RESTART_INTERVAL_SECONDS=120 ./creativesoundfix.sh
# When it is not set, the interval is randomized between 3 and 5 minutes
# (180 to 300 seconds) on every cycle, as described in the README.
FIXED_INTERVAL_SECONDS="${RESTART_INTERVAL_SECONDS:-}"
if [ -n "$FIXED_INTERVAL_SECONDS" ]; then
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

# Loop forever
while true; do
    if [ -n "$FIXED_INTERVAL_SECONDS" ]; then
        RESTART_INTERVAL_SECONDS="$FIXED_INTERVAL_SECONDS"
    else
        # Randomize interval between 3 and 5 minutes (180 to 300 seconds)
        RESTART_INTERVAL_SECONDS=$((RANDOM % 121 + 180))
    fi

    echo "----------------------------------------"
    echo "Waiting for ${RESTART_INTERVAL_SECONDS} seconds until next reset..."
    sleep "$RESTART_INTERVAL_SECONDS"

    echo "Performing surgical reset at $(date)..."
    # Kill the plugin. macOS launchd will restart it automatically.
    pkill -f "$PLUGIN_PROCESS_NAME"
    pkill_status=$?

    if [ "$pkill_status" -eq 0 ]; then
        echo "Successfully sent termination signal to '${PLUGIN_PROCESS_NAME}'."
        echo "macOS will now restart it automatically."
    else
        echo "Warning: Process '${PLUGIN_PROCESS_NAME}' not found. It may not have been running."
    fi
done
