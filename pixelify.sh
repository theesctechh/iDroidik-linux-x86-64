#!/bin/bash
# ⚠️ EXPERIMENTAL — make a freshly-installed Android look/behave like the Pixel-style setup:
# installs the FOSS apps placed in ./apks/ and applies the launcher + appearance config over adb.
set -u
cd "$(dirname "$0")"

# Linux paths
export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

bold(){ printf '\033[1m%s\033[0m\n' "$*"; }
ok(){ printf '\033[32m✓ %s\033[0m\n' "$*"; }
warn(){ printf '\033[33m! %s\033[0m\n' "$*"; }
a(){ adb "$@"; }

# Linux adb check
command -v adb >/dev/null 2>&1 || { warn "adb not found (sudo apt install adb)"; exit 1; }
a get-state >/dev/null 2>&1 || { warn "no device over adb — boot Android first with ./android.sh"; exit 1; }
[ "$(a shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] || warn "Android may not be fully booted yet — continuing anyway"
a root >/dev/null 2>&1; sleep 2

bold "1/4  Installing FOSS apps from ./apks/ …"
shopt -s nullglob 2>/dev/null || true
apks=(apks/*.apk)
if [ "${#apks[@]}" -eq 0 ]; then
  warn "no APKs in ./apks/ — run ./tools/fetch-apks.sh first, or drop APKs there"
else
  for apk in "${apks[@]}"; do
    printf '  %s … ' "$(basename "$apk")"
    if a install -r -g "$apk" >/dev/null 2>&1; then echo ok; else echo "skipped/failed"; fi
  done
fi

HOME_PKG=app.lawnchair
has_pkg(){ a shell pm path "$1" 2>/dev/null | grep -q package:; }

bold "2/4  Launcher: Lawnchair as home + Pixel appearance …"
if has_pkg "$HOME_PKG"; then
  a shell cmd package set-home-activity $HOME_PKG/.LawnchairLauncher >/dev/null 2>&1 && ok "Lawnchair set as home" || warn "could not set Lawnchair as home"
  
  if [ -f assets/lawnchair-appearance.preferences_pb ]; then
    a shell "monkey -p $HOME_PKG -c android.intent.category.LAUNCHER 1" >/dev/null 2>&1; sleep 4
    a push assets/lawnchair-appearance.preferences_pb /data/local/tmp/lc.pb >/dev/null 2>&1
    
    # Fixed the Android stat/chown bug here
    a shell 'DIR=/data/data/app.lawnchair/files/datastore; mkdir -p "$DIR"; \
      cp /data/local/tmp/lc.pb "$DIR/preferences.preferences_pb"; \
      chmod 600 "$DIR/preferences.preferences_pb"; \
      restorecon -R "$DIR" 2>/dev/null; rm -f /data/local/tmp/lc.pb; \
      kill $(pidof app.lawnchair) 2>/dev/null' >/dev/null 2>&1 && ok "Lawnchair appearance applied (circle icons)" || warn "appearance template not applied (set it in Lawnchair settings)"
  fi
else
  warn "Lawnchair not installed — put app.lawnchair APK in ./apks/ (and Lawnicons) and re-run"
fi

bold "3/4  System look: dark mode + gesture navigation …"
a shell cmd uimode night yes >/dev/null 2>&1 && ok "dark mode on" || warn "could not set dark mode"
a shell cmd overlay enable com.android.internal.systemui.navbar.gestural >/dev/null 2>&1 && ok "gesture navigation on" || warn "could not enable gesture nav"

bold "4/4  Wallpaper …"
if [ -f pixel/wallpaper.png ]; then
  if a push pixel/wallpaper.png /sdcard/Pictures/idroid-wallpaper.png >/dev/null 2>&1; then
    ok "wallpaper copied to the phone (Pictures/idroid-wallpaper.png)"
    echo "    set it via Wallpaper & style — a programmatic set isn't reliable on this GSI"
  else
    warn "could not copy wallpaper"
  fi
fi

# re-apply the launcher/UI by restarting SystemUI
a shell 'kill $(pidof com.android.systemui) 2>/dev/null' >/dev/null 2>&1
echo
ok "Pixel-ification done (best-effort). Re-check the home screen; run ./android.sh tune for performance."
echo "Install proprietary apps (TikTok, etc.) yourself from Aurora Store."
