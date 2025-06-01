#!/bin/bash

# Usage:
# ./mac-to-linux-wifi-transfer.sh user@linux-host

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 user@linux-host"
    exit 1
fi

REMOTE="$1"
EXPORT_FILE="/tmp/wifi-mac-export.txt"

echo "🔍 Exporting Wi-Fi networks from Mac..."

# Get list of SSIDs
SSIDS=$(networksetup -listpreferredwirelessnetworks en0 | tail -n +2)

# Create export file
echo "" > "$EXPORT_FILE"

for ssid in $SSIDS; do
    password=$(security find-generic-password -D "AirPort network password" -a "$ssid" -w 2>/dev/null)
    echo "SSID: $ssid" >> "$EXPORT_FILE"
    echo "Password: $password" >> "$EXPORT_FILE"
    echo "-----------------------------" >> "$EXPORT_FILE"
done

echo "✅ Exported to $EXPORT_FILE"

echo "📤 Sending export file to Linux: $REMOTE:/tmp/wifi-mac-export.txt"
scp "$EXPORT_FILE" "$REMOTE:/tmp/wifi-mac-export.txt"

echo "🚀 Running import on Linux..."

ssh "$REMOTE" bash -s << 'ENDSSH'
INPUT_FILE="/tmp/wifi-mac-export.txt"
CONNECTIONS_DIR="/etc/NetworkManager/system-connections"

while read -r line; do
  if [[ $line =~ ^SSID:\ (.*)$ ]]; then
    ssid="${BASH_REMATCH[1]}"
  fi

  if [[ $line =~ ^Password:\ (.*)$ ]]; then
    password="${BASH_REMATCH[1]}"
    config_path="$CONNECTIONS_DIR/$ssid.nmconnection"

    sudo bash -c "cat > \"$config_path\" <<EOF
[connection]
id=$ssid
uuid=$(uuidgen)
type=wifi
autoconnect=true

[wifi]
ssid=$ssid
mode=infrastructure

[wifi-security]
key-mgmt=wpa-psk
psk=$password

[ipv4]
method=auto

[ipv6]
method=auto
EOF
"

    sudo chmod 600 "$config_path"
    sudo chown root:root "$config_path"

    echo "Added Wi-Fi network $ssid"
  fi
done < "$INPUT_FILE"

sudo systemctl restart NetworkManager
echo "✅ Wi-Fi import completed on Linux."
ENDSSH

echo "🎉 Done!"
