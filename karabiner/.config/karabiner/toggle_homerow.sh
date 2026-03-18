#!/bin/bash
CLI="/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
CURRENT=$("$CLI" --show-current-profile-name 2>/dev/null)
if [ "$CURRENT" = "Default profile" ]; then
  "$CLI" --select-profile "No Homerow Mods"
else
  "$CLI" --select-profile "Default profile"
fi
