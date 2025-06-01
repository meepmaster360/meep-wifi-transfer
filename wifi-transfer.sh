#!/bin/bash

CONNECTIONS_DIR="/etc/NetworkManager/system-connections"
LOCAL_BACKUP_PATH="/tmp/wifi-backup"
DEFAULT_USB_PATH="/media/$USER"

# Prompt for SSH target
read -p "🔐 Enter remote SSH username (leave blank to skip SSH): " REMOTE_USER
read -p "🌐 Enter remote SSH host/IP (leave blank to skip SSH): " REMOTE_HOST
REMOTE_BACKUP_PATH="/home/$REMOTE_USER/wifi-backup"

function backup_wifi() {
    echo "📦 Backing up Wi-Fi profiles..."
    mkdir -p "$LOCAL_BACKUP_PATH"
    sudo cp -r "$CONNECTIONS_DIR"/* "$LOCAL_BACKUP_PATH"
    sudo chmod -R 644 "$LOCAL_BACKUP_PATH"/*
    sudo chown -R $USER:$USER "$LOCAL_BACKUP_PATH"
    echo "✅ Backup saved to $LOCAL_BACKUP_PATH"
}

function restore_wifi() {
    echo "🔄 Restoring Wi-Fi profiles on local machine..."
    if [ ! -d "$LOCAL_BACKUP_PATH" ]; then
        echo "❌ Backup not found: $LOCAL_BACKUP_PATH"
        return
    fi
    sudo cp "$LOCAL_BACKUP_PATH"/* "$CONNECTIONS_DIR/"
    sudo chmod 600 "$CONNECTIONS_DIR"/*
    sudo chown root:root "$CONNECTIONS_DIR"/*
    sudo systemctl restart NetworkManager
    echo "✅ Wi-Fi profiles restored locally"
}

function send_backup_ssh() {
    if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
        echo "❌ SSH username or host not set."
        return
    fi
    echo "🚀 Sending backup to $REMOTE_USER@$REMOTE_HOST..."
    scp -r "$LOCAL_BACKUP_PATH" "$REMOTE_USER@$REMOTE_HOST:~/"
    echo "✅ Sent to $REMOTE_USER@$REMOTE_HOST"
}

function remote_restore() {
    if [[ -z "$REMOTE_USER" || -z "$REMOTE_HOST" ]]; then
        echo "❌ SSH username or host not set."
        return
    fi
    echo "🖧 Running restore on remote machine..."
    ssh "$REMOTE_USER@$REMOTE_HOST" 'bash -s' << 'ENDSSH'
BACKUP_DIR="$HOME/wifi-backup"
TARGET_DIR="/etc/NetworkManager/system-connections"

echo "🔄 Restoring Wi-Fi profiles on remote..."

if [ ! -d "$BACKUP_DIR" ]; then
    echo "❌ Backup not found: $BACKUP_DIR"
    exit 1
fi

sudo cp "$BACKUP_DIR"/* "$TARGET_DIR/"
sudo chmod 600 "$TARGET_DIR"/*
sudo chown root:root "$TARGET_DIR"/*
sudo systemctl restart NetworkManager

echo "✅ Remote Wi-Fi restore complete!"
ENDSSH
}

function copy_to_usb() {
    echo "📁 Available USB devices:"
    ls "$DEFAULT_USB_PATH"
    read -p "💾 Enter USB name (as shown above): " USB_NAME
    USB_PATH="$DEFAULT_USB_PATH/$USB_NAME"

    if [ ! -d "$USB_PATH" ]; then
        echo "❌ USB not found at $USB_PATH"
        return
    fi

    echo "📤 Copying backup to USB..."
    mkdir -p "$USB_PATH/wifi-backup"
    cp -r "$LOCAL_BACKUP_PATH"/* "$USB_PATH/wifi-backup"
    echo "✅ Backup copied to USB: $USB_PATH/wifi-backup"
}

function restore_from_usb() {
    echo "📁 Available USB devices:"
    ls "$DEFAULT_USB_PATH"
    read -p "💾 Enter USB name (as shown above): " USB_NAME
    USB_PATH="$DEFAULT_USB_PATH/$USB_NAME/wifi-backup"

    if [ ! -d "$USB_PATH" ]; then
        echo "❌ No backup found at $USB_PATH"
        return
    fi

    echo "🔄 Restoring from USB..."
    sudo cp "$USB_PATH"/* "$CONNECTIONS_DIR/"
    sudo chmod 600 "$CONNECTIONS_DIR"/*
    sudo chown root:root "$CONNECTIONS_DIR"/*
    sudo systemctl restart NetworkManager
    echo "✅ Restored from USB"
}

function cleanup() {
    echo "🧹 Cleaning up local backup..."
    rm -rf "$LOCAL_BACKUP_PATH"
    echo "✅ Local backup deleted."
}

function show_menu() {
    echo ""
    echo "=========== Wi-Fi Transfer Menu ==========="
    echo "1. Backup Wi-Fi locally"
    echo "2. Restore Wi-Fi locally"
    echo "3. Send backup via SSH"
    echo "4. Restore remotely via SSH"
    echo "5. Copy backup to USB"
    echo "6. Restore backup from USB"
    echo "7. Cleanup local backup"
    echo "0. Exit"
    echo "==========================================="
    read -p "Choose an option: " CHOICE

    case "$CHOICE" in
        1) backup_wifi ;;
        2) restore_wifi ;;
        3) send_backup_ssh ;;
        4) remote_restore ;;
        5) copy_to_usb ;;
        6) restore_from_usb ;;
        7) cleanup ;;
        0) exit ;;
        *) echo "❌ Invalid option" ;;
    esac
}

# Loop menu
while true; do
    show_menu
done
