Awesome — here is a hybrid version of the Wi-Fi transfer tool that lets you choose:

✅ Local backup & restore

📤 Send/receive via SSH

📁 Copy to/from a USB drive

It's fully menu-driven, with interactive SSH target input and USB detection.

######

Also a combined cross-platform script that you run on the Mac to export Wi-Fi networks & passwords, then automatically send the backup file to the Linux machine via SSH, and run the import on Linux remotely

How to use:
Save as mac-to-linux-wifi-transfer.sh on your Mac.

Make executable:

bash
Copiar
Editar
chmod +x mac-to-linux-wifi-transfer.sh
Run it with your Linux SSH login:

bash
Copiar
Editar
./mac-to-linux-wifi-transfer.sh user@linux-host

🚀 COMO USAR (macOS/Linux/Windows)
Coloca import-wifi-to-linux.sh no mesmo diretório.

No Windows: Abre PowerShell e executa:

powershell
Copiar
Editar
.\export-and-send-wifi-windows.ps1 user@192.168.1.10
No macOS ou Linux:

bash
Copiar
Editar
bash export-and-send-wifi-mac.sh user@192.168.1.10
# ou
bash export-and-send-wifi-linux.sh user@192.168.1.10
