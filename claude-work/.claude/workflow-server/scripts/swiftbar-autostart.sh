#!/usr/bin/env bash
# Ensure SwiftBar auto-starts at login and survives crashes.
# Run once — installs macOS Login Item + lightweight keep-alive launchd agent.

set -euo pipefail

APP="/Applications/SwiftBar.app"
if [[ ! -d "${APP}" ]]; then
  echo "SwiftBar.app not found at ${APP}"
  echo "Install first: brew install --cask swiftbar"
  exit 1
fi

# 1. Add to Login Items via osascript (appears in System Settings → Login Items)
osascript <<APPLESCRIPT
tell application "System Events"
  if not (exists login item "SwiftBar") then
    make login item at end with properties {path:"${APP}", hidden:false}
    return "added"
  else
    return "already present"
  end if
end tell
APPLESCRIPT

# 2. Launch now if not running
if ! pgrep -f "SwiftBar.app/Contents/MacOS/SwiftBar" > /dev/null; then
  open "${APP}"
  echo "SwiftBar launched"
else
  echo "SwiftBar already running (pid $(pgrep -f SwiftBar | head -1))"
fi

# 3. (Optional) keep-alive launchd agent — restarts SwiftBar if it crashes
PLIST="${HOME}/Library/LaunchAgents/com.kelvin.swiftbar-keepalive.plist"
cat > "${PLIST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.kelvin.swiftbar-keepalive</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>-a</string>
    <string>SwiftBar</string>
  </array>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key><false/>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>/tmp/swiftbar-keepalive.log</string>
  <key>StandardErrorPath</key><string>/tmp/swiftbar-keepalive.err</string>
</dict>
</plist>
EOF

launchctl unload "${PLIST}" 2>/dev/null || true
launchctl load "${PLIST}"

echo ""
echo "Done."
echo "SwiftBar will start at login + restart if killed."
echo ""
echo "If icon is still not visible:"
echo "  • Menu bar may be hidden by notch — try Option+Cmd+drag to reorder icons"
echo "  • Force quit + reopen: pkill -f SwiftBar && open -a SwiftBar"
echo "  • Use Bartender / iBar if you have many menu bar items"
