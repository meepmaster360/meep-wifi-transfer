#!/bin/bash

set -e

# Arquivo temporário
TMP_FILE="/tmp/wifi-export.txt"

# Cores e título
TITLE="📶 Wi-Fi Transfer Tool"

# Função: detectar sistema operacional
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "mac"
    elif grep -qi microsoft /proc/version 2>/dev/null; then
        echo "windows"
    elif [[ "$(uname)" == "Linux" ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# Verifica dependências básicas
check_deps() {
    for cmd in whiptail ssh scp uuidgen nmcli sudo; do
        command -v $cmd >/dev/null || { echo "❌ Falta o comando '$cmd'. Instale com: sudo apt install $cmd"; exit 1; }
    done
}

# Exporta redes Wi-Fi no Linux
export_wifi_linux() {
    sudo chmod +r /etc/NetworkManager/system-connections/* 2>/dev/null
    > "$TMP_FILE"
    for file in /etc/NetworkManager/system-connections/*; do
        ssid=$(grep '^ssid=' "$file" | cut -d= -f2)
        psk=$(grep '^psk=' "$file" | cut -d= -f2)
        echo "SSID: $ssid" >> "$TMP_FILE"
        echo "Password: $psk" >> "$TMP_FILE"
        echo "------------------------" >> "$TMP_FILE"
    done
}

# Exporta redes no macOS
export_wifi_mac() {
    > "$TMP_FILE"
    networks=$(networksetup -listpreferredwirelessnetworks en0 | tail -n +2)
    for ssid in $networks; do
        psk=$(security find-generic-password -D "AirPort network password" -a "$ssid" -w 2>/dev/null || echo "")
        echo "SSID: $ssid" >> "$TMP_FILE"
        echo "Password: $psk" >> "$TMP_FILE"
        echo "------------------------" >> "$TMP_FILE"
    done
}

# Importa redes no Linux
import_wifi_linux() {
    sudo bash -c "
    while read -r line; do
        if [[ \$line =~ ^SSID:\ (.*)\$ ]]; then
            ssid=\"\${BASH_REMATCH[1]}\"
        fi
        if [[ \$line =~ ^Password:\ (.*)\$ ]]; then
            psk=\"\${BASH_REMATCH[1]}\"
            file=\"/etc/NetworkManager/system-connections/\$ssid.nmconnection\"
            cat > \"\$file\" <<EOF
[connection]
id=\$ssid
uuid=\$(uuidgen)
type=wifi
autoconnect=true

[wifi]
ssid=\$ssid
mode=infrastructure

[wifi-security]
key-mgmt=wpa-psk
psk=\$psk

[ipv4]
method=auto
[ipv6]
method=auto
EOF
            chmod 600 \"\$file\"
            chown root:root \"\$file\"
        fi
    done < \"$TMP_FILE\"
    systemctl restart NetworkManager
    "
}

# Envia para outro sistema via SSH
send_via_ssh() {
    remote=$(whiptail --inputbox "Insira o IP ou hostname remoto (formato user@ip):" 10 60 --title "$TITLE" 3>&1 1>&2 2>&3)
    if [ -z "$remote" ]; then return; fi

    scp "$TMP_FILE" "$remote:/tmp/wifi-export.txt"

    ssh "$remote" 'bash -s' <<'EOF'
#!/bin/bash
FILE="/tmp/wifi-export.txt"
CONN="/etc/NetworkManager/system-connections"

while read -r line; do
    if [[ $line =~ ^SSID:\ (.*)$ ]]; then
        ssid="${BASH_REMATCH[1]}"
    fi
    if [[ $line =~ ^Password:\ (.*)$ ]]; then
        psk="${BASH_REMATCH[1]}"
        file="$CONN/$ssid.nmconnection"
        sudo bash -c "cat > \"$file\" <<EOL
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
psk=$psk

[ipv4]
method=auto
[ipv6]
method=auto
EOL
chmod 600 \"$file\"
chown root:root \"$file\""
    fi
done < "$FILE"
sudo systemctl restart NetworkManager
EOF
    whiptail --msgbox "✅ Redes Wi-Fi importadas com sucesso via SSH!" 10 50 --title "$TITLE"
}

# Menu principal
main_menu() {
    while true; do
        choice=$(whiptail --title "$TITLE" --menu "O que deseja fazer?" 18 60 10 \
            "1" "Exportar redes Wi-Fi locais" \
            "2" "Exportar e enviar via SSH" \
            "3" "Importar redes de um ficheiro" \
            "4" "Sair" 3>&1 1>&2 2>&3)

        case $choice in
            1)
                case $(detect_os) in
                    linux) export_wifi_linux ;;
                    mac) export_wifi_mac ;;
                    *) whiptail --msgbox "SO não suportado." 10 40 ;; 
                esac
                whiptail --msgbox "✅ Redes exportadas para $TMP_FILE" 10 60 --title "$TITLE"
                ;;
            2)
                case $(detect_os) in
                    linux) export_wifi_linux ;;
                    mac) export_wifi_mac ;;
                    *) whiptail --msgbox "SO não suportado." 10 40 ;;
                esac
                send_via_ssh
                ;;
            3)
                file=$(whiptail --inputbox "Insira o caminho para o ficheiro Wi-Fi exportado:" 10 70 "$HOME/wifi-export.txt" 3>&1 1>&2 2>&3)
                if [ -f "$file" ]; then
                    cp "$file" "$TMP_FILE"
                    import_wifi_linux
                    whiptail --msgbox "✅ Importado com sucesso!" 10 40 --title "$TITLE"
                else
                    whiptail --msgbox "❌ Ficheiro não encontrado." 10 40 --title "$TITLE"
                fi
                ;;
            4) break ;;
            *) break ;;
        esac
    done
}

# Execução principal
check_deps
main_menu
