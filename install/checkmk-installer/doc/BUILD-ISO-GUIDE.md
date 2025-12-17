# Guida alla Generazione ISO CheckMK Installer

## Requisiti

- Sistema Linux (Ubuntu 24.04 o superiore raccomandato)
- Minimo 10GB di spazio disco libero
- Accesso root/sudo
- Connessione internet (per scaricare Ubuntu 24.04.3 ISO ~3.1GB)

## Preparazione Sistema

### 1. Installa le dipendenze necessarie

```bash
sudo apt-get update
sudo apt-get install -y xorriso isolinux squashfs-tools genisoimage wget rsync libarchive-tools
```

### 2. Clona il repository

```bash
git clone https://github.com/Coverup20/checkmk-tools.git
cd checkmk-tools/Install/checkmk-installer
```

## Generazione ISO

### Metodo 1: Esecuzione Diretta

```bash
# Assicurati di essere nella directory checkmk-installer
cd /path/to/checkmk-tools/Install/checkmk-installer

# Esegui lo script come root
sudo ./make-iso.sh
```

### Metodo 2: Con Docker (Raccomandato)

Crea un `Dockerfile`:

```dockerfile
FROM ubuntu:24.04

RUN apt-get update && apt-get install -y \
    xorriso \
    isolinux \
    squashfs-tools \
    genisoimage \
    wget \
    rsync \
    libarchive-tools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

CMD ["/bin/bash"]
```

Poi esegui:

```bash
# Costruisci l'immagine Docker
docker build -t iso-builder .

# Esegui il container montando il repository
docker run -it --privileged \
  -v $(pwd):/build \
  iso-builder

# All'interno del container
cd /build
./make-iso.sh
```

## Processo di Build

Lo script eseguirà automaticamente:

1. ✅ Controllo dipendenze
2. ⬇️ Download Ubuntu 24.04.3 LTS ISO (~3.1GB)
3. 📦 Estrazione ISO
4. ➕ Aggiunta CheckMK Installer
5. ⚙️ Configurazione boot UEFI/Legacy
6. 🔧 Creazione autostart
7. 📝 Configurazione preseed
8. 🏗️ Build ISO finale
9. 💾 Creazione checksums (MD5/SHA256)

## Output

L'ISO verrà creata in:
```
Install/checkmk-installer/iso-output/checkmk-installer-v1.0-amd64.iso
```

Dimensione attesa: ~3.2GB

## File Generati

```
iso-output/
├── checkmk-installer-v1.0-amd64.iso       # ISO bootabile
├── checkmk-installer-v1.0-amd64.iso.md5    # Checksum MD5
└── checkmk-installer-v1.0-amd64.iso.sha256 # Checksum SHA256
```

## Scrittura su USB

### Linux
```bash
sudo dd if=iso-output/checkmk-installer-v1.0-amd64.iso \
        of=/dev/sdX \
        bs=4M \
        status=progress \
        conv=fsync
```

### Windows
Usa uno di questi tool:
- **Rufus** (raccomandato): https://rufus.ie/
- **Balena Etcher**: https://www.balena.io/etcher/

### macOS
```bash
sudo dd if=iso-output/checkmk-installer-v1.0-amd64.iso \
        of=/dev/diskX \
        bs=4m
```

## Utilizzo ISO

### Opzione 1: Boot da USB
1. Scrivi ISO su USB
2. Boot dal dispositivo USB
3. Una volta avviato Ubuntu Live, esegui:
   ```bash
   cd /cdrom/checkmk-installer
   sudo ./installer.sh
   ```

### Opzione 2: Copia su Sistema
1. Boot da USB in modalità Live
2. Copia installer sul sistema:
   ```bash
   cp -r /cdrom/checkmk-installer ~/
   cd ~/checkmk-installer
   sudo ./installer.sh
   ```

### Opzione 3: Installazione Automatica
L'ISO include un preseed per installazione automatizzata con:
- Username: `admin`
- Password: `installer`
- Installer copiato in `/root/checkmk-installer`

## Troubleshooting

### "Missing dependencies"
```bash
sudo apt-get install xorriso isolinux squashfs-tools genisoimage wget rsync libarchive-tools
```

### "Failed to download Ubuntu ISO"
- Controlla la connessione internet
- Verifica che l'URL sia raggiungibile:
  ```bash
  wget --spider https://releases.ubuntu.com/24.04/ubuntu-24.04.3-live-server-amd64.iso
  ```

### "Failed to extract ISO"
- Assicurati di avere abbastanza spazio disco (minimo 10GB liberi)
- Verifica permessi di scrittura in `/tmp`

### "Failed to build ISO"
- Verifica che tutti i file in `iso-output/` siano scrivibili
- Controlla i log in `logs/iso-builder-*.log`

### "ISO not bootable"
- Usa `isohybrid` se disponibile:
  ```bash
  sudo apt-get install syslinux-utils
  isohybrid --uefi iso-output/checkmk-installer-v1.0-amd64.iso
  ```

## Verifica Integrità ISO

```bash
# Verifica MD5
md5sum -c iso-output/checkmk-installer-v1.0-amd64.iso.md5

# Verifica SHA256
sha256sum -c iso-output/checkmk-installer-v1.0-amd64.iso.sha256
```

## Note sulla Versione

- **Ubuntu Base**: 24.04.3 LTS (Noble Numbat)
- **Architettura**: AMD64 (64-bit)
- **Tipo**: Live Server ISO
- **Boot**: Hybrid (UEFI + Legacy BIOS)

## Aggiornamento Ubuntu Version

Per aggiornare alla versione più recente di Ubuntu, modifica in `make-iso.sh`:

```bash
UBUNTU_VERSION="24.04.3"  # Cambia versione qui
```

## Supporto

Per problemi o domande:
- Repository: https://github.com/Coverup20/checkmk-tools
- Issues: https://github.com/Coverup20/checkmk-tools/issues

## Changelog

### v1.0 (2025-11-24)
- ✅ Aggiornato a Ubuntu 24.04.3 LTS
- ✅ Supporto boot UEFI + Legacy BIOS
- ✅ Installer pre-configurato
- ✅ Preseed per installazione automatica
