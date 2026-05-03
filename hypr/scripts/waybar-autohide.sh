#!/usr/bin/env bash

BAR_HEIGHT=40        # match your waybar height
EDGE_THRESHOLD=5     # px from top to trigger show
HIDE_DELAY=0.3       # seconds before hiding

visible=1

while true; do
    read -r X Y < <(hyprctl cursorpos)

    if (( Y <= EDGE_THRESHOLD )); then
        if (( visible == 0 )); then
            pkill -USR2 waybar
            visible=1
        fi
    else
        if (( visible == 1 )); then
            sleep "$HIDE_DELAY"
            read -r _ Y2 < <(hyprctl cursorpos)
            if (( Y2 > EDGE_THRESHOLD )); then
                pkill -USR1 waybar
                visible=0
            fi
        fi
    fi

    sleep 0.05
done
