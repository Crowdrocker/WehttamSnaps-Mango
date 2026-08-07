#!/bin/bash

# This script lists all open windows with their Class and App_ID
# to help you fix your Sway workspace assignments.

echo -e "WINDOW TITLE | APP_ID | CLASS"
echo -e "--------------------------------------------------------"

swaymsg -t get_tree | jq -r '
  .. | select(.type? == "con" or .type? == "floating_con")
  | select(.window_properties? or .app_id?)
  | "\(.name) | \(.app_id // "N/A") | \(.window_properties.class // "N/A")"' | column -t -s "|"
