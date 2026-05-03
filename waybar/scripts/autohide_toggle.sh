#!/bin/bash

# Configuration
WAYBAR_HEIGHT=38 # Adjust this to your Waybar's actual height
WAYBAR_POSITION="top" # "top" or "bottom"
HIDE_DELAY=3 # seconds
STATE_FILE="/tmp/waybar_autohide_state.json"
LOG_FILE="/tmp/autohide_toggle.log" # Added log file

# Initial state
CURRENT_STATE="visible"
LAST_HOVER_TIME=$(date +%s)

# Clear log file on start
> "$LOG_FILE"
echo "$(date): Script started." >> "$LOG_FILE"

# Function to get Waybar geometry and mouse position
get_info() {
    # Get Waybar window geometry
    # Look for client with "waybar" in class or title
    WAYBAR_CLIENT_INFO=$(hyprctl clients -j | jq -r '.[] | select((.class | contains("waybar")) or (.title | contains("waybar"))) | .at[0], .at[1], .size[0], .size[1]')

    if [ -z "$WAYBAR_CLIENT_INFO" ]; then
        echo "$(date): Could not find Waybar client info with 'waybar' in class or title." >> "$LOG_FILE"
        echo "$(date): Full hyprctl clients -j output:" >> "$LOG_FILE"
        hyprctl clients -j >> "$LOG_FILE"
        # Try a more general approach if specific Waybar client not found (e.g., first window with no specific title/class)
        WAYBAR_CLIENT_INFO=$(hyprctl clients -j | jq -r '.[0] | .at[0], .at[1], .size[0], .size[1]')
    fi

    read -r wx wy ww wh <<< "$WAYBAR_CLIENT_INFO"

    # Get cursor position
    CURSOR_POS=$(hyprctl cursorpos -j | jq -r '(.x|tostring) + " " + (.y|tostring)')
    read -r cx cy <<< "$CURSOR_POS"

    echo "$wx $wy $ww $wh $cx $cy"
}

# Function to check if mouse is over Waybar
is_mouse_over_waybar() {
    local wx wy ww wh cx cy
    read -r wx wy ww wh cx cy <<< "$1"

    echo "$(date): Waybar Geometry: x=$wx y=$wy w=$ww h=$wh | Cursor Pos: x=$cx y=$cy" >> "$LOG_FILE"

    if [ -z "$wx" ] || [ -z "$wy" ] || [ -z "$ww" ] || [ -z "$wh" ]; then
        echo "$(date): Waybar geometry not found. Not hovering." >> "$LOG_FILE"
        return 1
    fi

    if (( cx >= wx && cx <= wx + ww && cy >= wy && cy <= wy + wh )); then
        echo "$(date): Mouse is over Waybar." >> "$LOG_FILE"
        return 0 # Mouse is over Waybar
    else
        echo "$(date): Mouse is NOT over Waybar." >> "$LOG_FILE"
        return 1 # Mouse is not over Waybar
    fi
}

# Function to set Waybar state
set_waybar_state() {
    local new_state="$1"
    if [ "$CURRENT_STATE" != "$new_state" ]; then
        CURRENT_STATE="$new_state"
        echo "$(date): Changing state to $new_state" >> "$LOG_FILE"
        if [ "$new_state" == "hidden" ]; then
            echo '{"class": "hidden"}' > "$STATE_FILE"
        else
            echo '{"class": ""}' > "$STATE_FILE"
        fi
        pkill -RTMIN+8 waybar # Trigger Waybar update, if using systemd hook for custom modules
    fi
}

# Ensure the state file exists initially
echo '{"class": ""}' > "$STATE_FILE"
echo "$(date): Initial state file created: $(cat "$STATE_FILE")" >> "$LOG_FILE"

# Main loop
while true; do
    INFO=$(get_info)
    if is_mouse_over_waybar "$INFO"; then
        LAST_HOVER_TIME=$(date +%s)
        set_waybar_state "visible"
    else
        CURRENT_TIME=$(date +%s)
        if (( CURRENT_TIME - LAST_HOVER_TIME >= HIDE_DELAY )); then
            set_waybar_state "hidden"
        else
            echo "$(date): Mouse left Waybar, but delay not met. Time since hover: $((CURRENT_TIME - LAST_HOVER_TIME))s" >> "$LOG_FILE"
        fi
    fi
    sleep 0.1 # Check every 100ms
done
