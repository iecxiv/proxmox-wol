#!/bin/bash
(
    set -e

    SCRIPT=/root/scripts/wol.sh
    BACKUP="${SCRIPT}.bak.$(date +%Y%m%d-%H%M%S)"

    cp -a "$SCRIPT" "$BACKUP"
    echo "Copia de seguridad: $BACKUP"

    if grep -Fq 'udp port 7' "$SCRIPT"; then
        echo "El script ya contiene udp port 7; no se modifica."
    elif grep -Fq 'udp port 9' "$SCRIPT"; then
        sed -i 's/udp port 9/udp port 7 or udp port 9/g' "$SCRIPT"
    else
        echo "No se encuentra el filtro esperado. No se modifica el script."
        exit 1
    fi

    bash -n "$SCRIPT"
    echo '=== FILTRO RESULTANTE ==='
    grep -n 'tcpdump' "$SCRIPT"

    systemctl restart pve-wakeonlan
    systemctl status pve-wakeonlan --no-pager -l
)
