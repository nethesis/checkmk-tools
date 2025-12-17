# Quick Guide - Generare ISO con WSL

## Una volta che docker-desktop è pronto in WSL:

### Metodo 1: Con Docker in WSL (Raccomandato)
```powershell
# Da PowerShell Windows
wsl

# Dentro WSL
cd /mnt/c/Users/Gaming/checkmk-tools/Install/checkmk-installer
docker build -t checkmk-iso-builder .
docker run --rm --privileged -v $(pwd):/build checkmk-iso-builder bash -c "cd /build && ./make-iso.sh"
```

### Metodo 2: Direttamente in WSL (se Docker non parte)
```powershell
# Da PowerShell Windows
wsl

# Dentro WSL - Installa dipendenze
sudo apt-get update
sudo apt-get install -y xorriso isolinux syslinux-utils squashfs-tools genisoimage wget rsync libarchive-tools

# Vai alla cartella del progetto
cd /mnt/c/Users/Gaming/checkmk-tools/Install/checkmk-installer

# Esegui lo script
sudo ./make-iso.sh
```

### Metodo 3: Script automatico per WSL
```powershell
# Crea e esegui questo script
wsl bash -c "cd /mnt/c/Users/Gaming/checkmk-tools/Install/checkmk-installer && sudo apt-get update && sudo apt-get install -y xorriso isolinux syslinux-utils squashfs-tools genisoimage wget rsync libarchive-tools && sudo ./make-iso.sh"
```

## Output
L'ISO verrà creata in:
```
C:\Users\Gaming\checkmk-tools\Install\checkmk-installer\iso-output\checkmk-installer-v1.0-amd64.iso
```

## Note
- Il processo richiede ~10GB di spazio libero
- Download Ubuntu 24.04.3: ~3.1GB
- Tempo stimato: 10-20 minuti
