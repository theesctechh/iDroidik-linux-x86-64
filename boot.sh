#!/bin/bash
# Usage: ./boot.sh linux|android
# Boots Project Sandcastle: palera1n's native checkm8 
# The old pongoOS is exctracted through checkra1n 0.10.1
# (newer pongo can't load the Sandcastle image; 0.10.1 itself crashes on macOS for some reason).
set -u
cd "$(dirname "$0")"

# --- CPU CHECK ---
CPU_VENDOR=$(grep -m 1 'vendor_id' /proc/cpuinfo | awk '{print $3}')

if [ "$CPU_VENDOR" == "AuthenticAMD" ]; then
    echo -e "\e[33m[!] AMD CPU detected.\e[0m"
    echo -e "\e[33m[!] Modern Linux USB stacks often fail checkm8 on Ryzen (error -75).\e[0m"
    echo -e "\e[32m[+] Recommended fix: Use palen1x on a USB drive to inject the payload.\e[0m"
    echo -e "\e[32m[+] Run: sudo ./palen1x -cp (or your specific palen1x command)\e[0m"

    read -p "Do you want to try running the native script anyway? (y/N) " response
    if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        exit 1
    fi
elif [ "$CPU_VENDOR" == "GenuineIntel" ]; then
    echo -e "\e[32m[+] Intel CPU detected. Proceeding with native checkm8...\e[0m"
fi
# --- /CPU CHECK ---

TARGET="${1:-linux}"
if [ "$TARGET" = android ]; then IMG=android-sandcastle/Android.lzma; DTB=android-sandcastle/dtbpack
else IMG=linux/Linux.lzma; DTB=linux/dtbpack; fi

OUT="$PWD/checkra1n-$TARGET.out"
echo "[boot] checkra1n 0.10.1 (checkra1n -cp) — put the iPhone into DFU"
"${CHECKRA1N:-./checkra1n-x86_64}" -cp < <(sleep 86400) > "$OUT" 2>&1 &
P=$!

last=""
while kill -0 $P 2>/dev/null; do
  line=$(grep -E "Found device|DFU|checkm8|Booting|Booted|pongo|Pongo|rror|Waiting" "$OUT" | tail -1)
  [ "$line" != "$last" ] && [ -n "$line" ] && echo "[checkra1n] $line" && last="$line"
  sleep 1
done
echo "[boot] checkra1n exited"
tail -5 "$OUT" | sed 's/^/[checkra1n-tail] /'

sleep 3
echo "[boot] uploading $IMG"
./android-sandcastle/load-linux.mac "$IMG" "$DTB" 2>&1 | sed 's/^/[load-linux] /'
echo "[boot] load-linux exit ${PIPESTATUS[0]}"
echo "[boot] done"
