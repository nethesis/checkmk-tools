#!/bin/bash
# Aumenta swap da 8GB a 16GB su server CheckMK
# Uso: su
do ./increase-swap.sh [--yes]

set -euo pipefail

# Flag per saltare conferme
AUTO_YES=false
if [[ "${1:-}" == "--yes" ]] || [[ "${1:-}" == "-y" ]]; then
    AUTO_YES=true
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== AUMENTO SWAP A 16GB ===${NC}\n"

# Verifica root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Questo script deve essere eseguito come root${NC}"
    exit 1
fi

# Mostra situazione attuale
echo -e "${YELLOW}Situazione attuale:${NC}"
free -h
echo ""
swapon --show
echo ""

# Identifica swapfile esistente
SWAPFILE=$(swapon --show=NAME --noheadings | head -n1)
if [[ -z "$SWAPFILE" ]]; then
    echo -e "${RED}Nessuno swapfile attivo trovato${NC}"
    if [[ "$AUTO_YES" == true ]]; then
    SWAPFILE="/swapfile"
        echo -e "${GREEN}Creazione nuovo swapfile: $SWAPFILE${NC}"
    else
        echo "Vuoi creare un nuovo swapfile da 16GB? (s/n)"
        read -r CREATE_NEW
        if [[ "$CREATE_NEW" =~ ^[Ss]$ ]]; then
    SWAPFILE="/swapfile"
        else
            exit 1
        fi
    fi
else
    echo -e "${GREEN}Swapfile esistente: $SWAPFILE${NC}"
fi

SWAP_SIZE_OLD=$(swapon --show=SIZE --noheadings --bytes | head -n1)
SWAP_SIZE_OLD_GB=$((SWAP_SIZE_OLD / 1024 / 1024 / 1024))

echo -e "\n${YELLOW}Dimensione swap attuale: ${SWAP_SIZE_OLD_GB}GB${NC}"
echo -e "${YELLOW}Nuova dimensione: 16GB${NC}\n"

if [[ "$AUTO_YES" == false ]]; then
    echo "Procedere? (s/n)"
    read -r CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Ss]$ ]]; then
    echo "Operazione annullata"
    exit 0
    fi
else
    echo -e "${GREEN}Modalità automatica: procedura avviata${NC}"
fi

# Disattiva swap esistente
echo -e "\n${YELLOW}1. Disattivazione swap...${NC}"
if [[ -n "$SWAPFILE" ]] && swapon --show | grep -q "$SWAPFILE"; then
    swapoff "$SWAPFILE"
    echo -e "${GREEN}✓ Swap disattivato${NC}"
fi

# Rimuovi vecchio swapfile
if [[ -f "$SWAPFILE" ]]; then
    echo -e "${YELLOW}2. Rimozione vecchio swapfile...${NC}"
    rm -f "$SWAPFILE"
    echo -e "${GREEN}✓ Vecchio swapfile rimosso${NC}"
fi

# Crea nuovo swapfile 16GB
echo -e "${YELLOW}3. Creazione swapfile 16GB (può richiedere alcuni minuti)...${NC}"
dd if=/dev/zero of="$SWAPFILE" bs=1M count=16384 status=progress
chmod 600 "$SWAPFILE"
echo -e "${GREEN}✓ Swapfile creato${NC}"

# Formatta come swap
echo -e "${YELLOW}4. Formattazione swap...${NC}"
mkswap "$SWAPFILE"
echo -e "${GREEN}✓ Swap formattato${NC}"

# Attiva swap
echo -e "${YELLOW}5. Attivazione swap...${NC}"
swapon "$SWAPFILE"
echo -e "${GREEN}✓ Swap attivato${NC}"

# Verifica entry in fstab
echo -e "${YELLOW}6. Verifica fstab...${NC}"
if ! grep -q "^$SWAPFILE" /etc/fstab; then
    echo "$SWAPFILE none swap sw 0 0" >> /etc/fstab
    echo -e "${GREEN}✓ Entry aggiunta a /etc/fstab${NC}"
else
    echo -e "${GREEN}✓ Entry già presente in /etc/fstab${NC}"
fi

# Ottimizza swappiness (usa swap solo quan
do necessario)
echo -e "${YELLOW}7. Ottimizzazione swappiness...${NC}"
if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    sysctl -w vm.swappiness=10
    echo -e "${GREEN}✓ Swappiness impostato a 10 (conservativo)${NC}"
else
    echo -e "${GREEN}✓ Swappiness già configurato${NC}"
fi

# Mostra risultato finale
echo -e "\n${GREEN}=== OPERAZIONE COMPLETATA ===${NC}\n"
echo -e "${YELLOW}Nuova configurazione swap:${NC}"
free -h
echo ""
swapon --show
echo ""
echo -e "${GREEN}✓ Swap aumentato a 16GB con successo!${NC}"
echo -e "${YELLOW}Nota: Il sistema userà lo swap solo quan
do necessario (swappiness=10)${NC}"
