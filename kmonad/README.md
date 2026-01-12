# Kmonad

Keyboard remapping tool. Config uses `.kbd` files with Lisp-like syntax.

## .kbd File Structure

```lisp
;; 1. CONFIGURATION - input/output devices
(defcfg
  input (iokit-name "Apple Internal Keyboard / Trackpad")  ;; macOS
  output (kext)
  fallthrough true  ;; non-mapped keys work normally
)

;; 2. SOURCE LAYOUT - your physical keyboard layout
(defsrc
  esc  f1   f2   ...
  grv  1    2    ...
  tab  q    w    e    r    t    ...
  caps a    s    d    f    g    ...
  lsft z    x    c    v    b    ...
)

;; 3. ALIASES - custom key behaviors
(defalias
  hyp (around ctl (around alt (around met sft)))     ;; hyper key
  ctl_a (tap-hold-next-release 150 a lctl)           ;; tap=a, hold=ctrl
)

;; 4. LAYERS - remapped layouts
(deflayer default
  _    _    _    ...   ;; _ = transparent (use original key)
  _    _    _    ...
  _    _    _    _    _    _    ...
  @hyp @ctl_a ...      ;; @alias = use the alias
)
```

## Key Concepts

| Syntax | Meaning |
|--------|---------|
| `_` | Transparent - pass through original key |
| `XX` | Block/disable the key |
| `@name` | Use an alias |
| `(tap-hold-next-release ms tap hold)` | Tap for one key, hold for another |
| `(around key1 key2)` | Press key1 while pressing key2 |
| `(layer-toggle name)` | Switch to layer while held |

## Home Row Mods Example

```lisp
(defalias
  ;; Left hand: A=Ctrl, S=Alt, D=Cmd, F=Shift
  ctl_a (tap-hold-next-release 150 a lctl)
  alt_s (tap-hold-next-release 150 s lalt)
  met_d (tap-hold-next-release 150 d lmet)
  sft_f (tap-hold-next-release 150 f lsft)

  ;; Right hand: J=Shift, K=Cmd, L=Alt, ;=Ctrl
  sft_j (tap-hold-next-release 150 j rsft)
  met_k (tap-hold-next-release 150 k rmet)
  alt_l (tap-hold-next-release 150 l lalt)
  ctl_; (tap-hold-next-release 150 ; rctl)
)
```

## macOS Setup

### 1. Install kmonad

```bash
# Build from source or download binary
# Place binary at ~/kmonadbin (or wherever)
chmod +x ~/kmonadbin
```

### 2. Install Dext (kernel extension)

Kmonad needs the Karabiner VirtualHIDDevice driver:
```bash
# Download from: https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases
# Install the .pkg file
# Enable in System Preferences → Privacy & Security
```

### 3. Create launchd plist

Save as `~/Library/LaunchAgents/local.kmonad.plist`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>local.kmonad</string>
    <key>Program</key>
    <string>/Users/YOUR_USERNAME/kmonadbin</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Users/YOUR_USERNAME/kmonadbin</string>
      <string>/Users/YOUR_USERNAME/.kmonad.kbd</string>
    </array>
    <key>RunAtLoad</key>
    <true />
    <key>StandardOutPath</key>
    <string>/tmp/kmonad.stdout</string>
    <key>StandardErrorPath</key>
    <string>/tmp/kmonad.stderr</string>
  </dict>
</plist>
```

### 4. Load/manage the service

```bash
# Load (start on boot)
launchctl load ~/Library/LaunchAgents/local.kmonad.plist

# Unload (stop)
launchctl unload ~/Library/LaunchAgents/local.kmonad.plist

# Check status
launchctl list | grep kmonad

# View logs
cat /tmp/kmonad.stdout
cat /tmp/kmonad.stderr
```

### 5. Manual run (for testing)

```bash
sudo ~/kmonadbin ~/.kmonad.kbd
```

## Finding Your Keyboard Name

```bash
# List available keyboards
ioreg -n IOHIDKeyboard -r | grep -e 'class IOHIDKeyboard' -e '"Product"'
```

## Resources

- [Kmonad GitHub](https://github.com/kmonad/kmonad)
- [Kmonad Tutorial](https://github.com/kmonad/kmonad/blob/master/keymap/tutorial.kbd)
