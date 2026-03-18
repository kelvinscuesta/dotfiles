# Kmonad — Homerow Mods on macOS

Keyboard remapping via [kmonad](https://github.com/kmonad/kmonad). Caps Lock becomes Hyper, home row keys double as modifiers when held.

## Current Layout

| Key | Tap | Hold |
|-----|-----|------|
| Caps Lock | — | Hyper (Ctrl+Alt+Cmd+Shift) |
| `a` | a | Left Control |
| `s` | s | Left Alt/Option |
| `d` | d | Left Command |
| `f` | f | Left Shift |
| `j` | j | Right Shift |
| `k` | k | Right Command |
| `l` | l | Left Alt/Option |
| `;` | ; | Right Control |

Fn key toggles a function layer (top row → real F1-F12).

All tap-hold keys use `tap-hold-next-release` with 150ms threshold.

## Bootstrap on a New Mac

### 1. Install the Karabiner DriverKit VirtualHIDDevice

kmonad needs this driver to output synthetic key events on macOS.

```bash
# Download latest .pkg from:
# https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases
# Install the .pkg, then activate:
/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS/Karabiner-VirtualHIDDevice-Manager activate
```

After install, go to **System Settings → Privacy & Security → Input Monitoring** and allow the driver if prompted.

### 2. Get the kmonad binary

```bash
# Option A: Download a pre-built release (if available for your arch)
# https://github.com/kmonad/kmonad/releases

# Option B: Build from source with stack
git clone https://github.com/kmonad/kmonad.git ~/kmonad
cd ~/kmonad
stack build --copy-bins  # installs to ~/.local/bin/kmonad
```

### 3. Stow the config

```bash
cd ~/dotfiles
stow kmonad   # symlinks .kmonad.kbd → ~/.kmonad.kbd
```

### 4. Install the LaunchDaemon

The plist runs kmonad as root at boot (required for input capture on macOS).

```bash
# Edit the plist to replace YOUR_USERNAME with your actual username
sed "s/YOUR_USERNAME/$(whoami)/g" ~/dotfiles/kmonad/local.kmonad.plist \

  | sudo tee /Library/LaunchDaemons/local.kmonad.plist > /dev/null

# Load the daemon
sudo launchctl bootstrap system/ /Library/LaunchDaemons/local.kmonad.plist
```

### 5. Grant Input Monitoring permission

Go to **System Settings → Privacy & Security → Input Monitoring** and add `~/kmonadbin` (or the terminal you run it from when testing manually).

### 6. Verify

```bash
# Check it's running
sudo launchctl list | grep kmonad

# Check logs if something's wrong
cat /tmp/kmonad.stdout
cat /tmp/kmonad.stderr

# Test manually (stop daemon first)
sudo launchctl bootout system/local.kmonad
sudo ~/.local/bin/kmonad ~/.kmonad.kbd
```

## Managing the Daemon

```bash
# Stop
sudo launchctl bootout system/local.kmonad

# Start
sudo launchctl bootstrap system/ /Library/LaunchDaemons/local.kmonad.plist

# Restart (after config changes)
sudo launchctl bootout system/local.kmonad && \
sudo launchctl bootstrap system/ /Library/LaunchDaemons/local.kmonad.plist
```

## Finding Your Keyboard Name

If using an external keyboard, you'll need to update `input` in `.kmonad.kbd`:

```bash
ioreg -n IOHIDKeyboard -r | grep -e 'class IOHIDKeyboard' -e '"Product"'
```

## .kbd Syntax Reference

| Syntax | Meaning |
|--------|---------|
| `_` | Transparent — pass through original key |
| `XX` | Block/disable the key |
| `@name` | Use an alias |
| `(tap-hold-next-release ms tap hold)` | Tap for one key, hold for another |
| `(around key1 key2)` | Press key1 while pressing key2 |
| `(layer-toggle name)` | Switch to layer while held |

## Resources

- [kmonad GitHub](https://github.com/kmonad/kmonad)
- [kmonad tutorial](https://github.com/kmonad/kmonad/blob/master/keymap/tutorial.kbd)
- [Karabiner DriverKit releases](https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases)
