#!/bin/bash

# ----- Paths -----
CONNECTIONS_DIR="/etc/NetworkManager/system-connections"
LOCAL_BACKUP_PATH="/tmp/wifi-backup"
DEFAULT_USB_PATH="/media/$USER"

# ----- Ensure zenity is installed -----
if ! command -v zenity &> /dev/null; then
    echo "Zenity not installed. Installing..."
    sudo apt install zenity -y
fi

# ----- Functions -----

backup_wifi() {
    mkdir -p "$LOCAL_BACKUP_PATH"
    sudo cp -r "$CONNECTIONS_DIR"/* "$LOCAL_BACKUP_PATH"
    sudo chmod -R 644 "$LOCAL_BACKUP_PATH"/*
    sudo chown -R $USER:$USER "$LOCAL_BACKUP_PATH"
    zenity --info --text="✅ Wi-Fi profiles backed up to $LOCAL_BACKUP_PATH"
}

restore_wifi() {
    if [ ! -d "$LOCAL_BACKUP_PATH" ]; then
        zenity --error --text="❌ Backup not found at $LOCAL_BACKUP_PATH"
        return
    fi
    sudo cp "$LOCAL_BACKUP_PATH"/* "$CONNECTIONS_DIR/"
    sudo chmod 600 "$CONNECTIONS_DIR"/*
    sudo chown root:root "$CONNECTIONS_DIR"/*
    sudo systemctl restart NetworkManager
    zenity --info --text="✅ Wi-Fi profiles restored locally"
}

send_backup_ssh() {
    REMOTE_USER=$(zenity --entry --title="SSH Username" --text="Enter remote SSH username:")
    REMOTE_HOST=$(zenity --entry --title="SSH Host/IP" --text="Enter remote SSH host or IP:")
    if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
        zenity --error --text="Missing SSH credentials."
        return
    fi
    scp -r "$LOCAL_BACKUP_PATH" "$REMOTE_USER@$REMOTE_HOST:~/"
    zenity --info --text="✅ Backup sent to $REMOTE_USER@$REMOTE_HOST"
}

remote_restore() {
    REMOTE_USER=$(zenity --entry --title="SSH Username" --text="Enter remote SSH username:")
    REMOTE_HOST=$(zenity --entry --title="SSH Host/IP" --text="Enter remote SSH host or IP:")
    if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
        zenity --error --text="Missing SSH credentials."
        return
    fi
    ssh "$REMOTE_USER@$REMOTE_HOST" 'bash -s' << 'ENDSSH'
BACKUP_DIR="$HOME/wifi-backup"
TARGET_DIR="/etc/NetworkManager/system-connections"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ No backup found"
    exit 1
fi

sudo cp "$BACKUP_DIR"/* "$TARGET_DIR/"
sudo chmod 600 "$TARGET_DIR"/*
sudo chown root:root "$TARGET_DIR"/*
sudo systemctl restart NetworkManager
ENDSSH
    zenity --info --text="✅ Wi-Fi restored on remote machine"
}

copy_to_usb() {
    USB_PATH=$(zenity --file-selection --directory --title="Select USB Drive Destination")
    if [ -z "$USB_PATH" ]; then
        zenity --error --text="No USB path selected."
        return
    fi
    mkdir -p "$USB_PATH/wifi-backup"
    cp -r "$LOCAL_BACKUP_PATH"/* "$USB_PATH/wifi-backup"
    zenity --info --text="✅ Backup copied to USB"
}

restore_from_usb() {
    USB_PATH=$(zenity --file-selection --directory --title="Select USB Backup Folder")
    if [ ! -d "$USB_PATH" ]; then
        zenity --error --text="Invalid path"
        return
    fi
    sudo cp "$USB_PATH"/* "$CONNECTIONS_DIR/"
    sudo chmod 600 "$CONNECTIONS_DIR"/*
    sudo chown root:root "$CONNECTIONS_DIR"/*
    sudo systemctl restart NetworkManager
    zenity --info --text="✅ Restored from USB"
}

cleanup() {
    rm -rf "$LOCAL_BACKUP_PATH"
    zenity --info --text="🧹 Local backup deleted"
}

# ----- GUI Menu -----

while true; do
    CHOICE=$(zenity --list --title="Wi-Fi Transfer Tool" \
        --column="Option" --column="Description" \
        1 "Backup Wi-Fi locally" \
        2 "Restore Wi-Fi locally" \
        3 "Send backup via SSH" \
        4 "Restore Wi-Fi remotely (SSH)" \
        5 "Copy backup to USB" \
        6 "Restore from USB" \
        7 "Delete local backup" \
        0 "Exit")

    case "$CHOICE" in
        1) backup_wifi ;;
        2) restore_wifi ;;
        3) send_backup_ssh ;;
        4) remote_restore ;;
        5) copy_to_usb ;;
        6) restore_from_usb ;;
        7) cleanup ;;
        0|""|Cancel) break ;;
        *) zenity --error --text="Invalid choice." ;;
    esac
done
