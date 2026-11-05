# proxmox-wol

[English](README.md) | Español

Wake-on-LAN para arrancar VM y contenedores LXC en un host Proxmox VE encendido. Se conservan el wol.sh funcional original y su servicio systemd.

## Instalación online

Los comandos requieren un repositorio PÚBLICO. Si sigue privado, la descarga sin autenticación fallará. Ejecutar como root en la shell del host Proxmox, no dentro de un invitado. Para lanzar los comandos debe estar instalado curl:

```bash
apt-get update && apt-get install -y curl ca-certificates
```

Instalar con vmbr0:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh)" -- install
```

Elegir otro bridge existente:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh)" -- install --interface vmbr1
```

Desinstalar:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh)" -- uninstall
```

Estos comandos ejecutan código remoto como root. Revisar el código antes. Para evitar iniciar Bash tras una descarga fallida y poder inspeccionar el archivo:

```bash
curl -fSL https://raw.githubusercontent.com/iecxiv/proxmox-wol/main/wol_install.sh -o /root/wol_install.sh
# Revisar el archivo descargado antes de ejecutarlo:
less /root/wol_install.sh
# Ejecutar solo tras una descarga correcta y revisión:
bash /root/wol_install.sh install --interface vmbr0
```

El instalador descarga wol.sh y pve-wakeonlan.service desde main, instala las dependencias curl/tcpdump si faltan, valida interfaz y sintaxis Bash, guarda los archivos anteriores en /root/proxmox-wol-backup.* e instala, habilita y reinicia el servicio. Si falla el despliegue, intenta restaurar archivos y estado activo/habilitado anterior; revisar el resultado manualmente. Los cambios de paquetes no se revierten. Se comprueba que el servicio esté activo, no el funcionamiento WoL completo. El instalador online todavía no se ha probado en tu host.

La desinstalación elimina /root/scripts/wol.sh y /etc/systemd/system/pve-wakeonlan.service después de deshabilitar el servicio. Conserva copias, paquetes e instalador descargado. No restaura automáticamente una instalación anterior.

## Archivos

- wol_install.sh: instalación/desinstalación online.
- wol.sh: script original, escucha Ethernet WoL 0x0842 y UDP 7/9 en vmbr0.
- pve-wakeonlan.service: ejecuta /root/scripts/wol.sh como root.
- fix-wol-port.sh: parche anterior para UDP 7; innecesario en instalaciones nuevas.

## Configuración y prueba

Consultar interfaces con ip -br link. El instalador cambia la interfaz en la copia instalada, no en el original del repositorio. Usar la MAC configurada en la VM/LXC objetivo, no la del host ni de interfaces auxiliares. Sustituir 123 por el ID real:

```bash
qm config 123
# Para LXC:
pct config 123
systemctl status pve-wakeonlan --no-pager -l
journalctl -fu pve-wakeonlan
```

Con el invitado detenido, enviar desde la red un paquete mágico a su MAC mediante UDP 7 o 9 y la dirección broadcast correspondiente. Capturar en otra terminal (adaptar vmbr0 si procede):

```bash
tcpdump -ni vmbr0 -e -vv -XX '(ether proto 0x0842) or (udp port 7) or (udp port 9)'
```

## Funcionamiento y limitaciones

El script extrae una MAC de tcpdump, busca primero configuraciones locales de VM y después LXC, y arranca la primera coincidencia si interpreta el estado como stopped. El host físico debe estar encendido. No implementa arranque entre nodos.

Espera cinco segundos antes de cada captura; repetir el envío si hace falta. El analizador sed depende de una posición fija de la salida y no valida completamente el paquete mágico. Conserva expansiones sin comillas del original; una MAC vacía no se gestiona de forma segura. Los errores de tcpdump se ocultan. Es una versión funcional aportada, no una implementación endurecida. Usar solo en redes de confianza: no autentica solicitudes y se ejecuta como root. No exponer a Internet.

Sin paquetes, comprobar emisor, interfaz y puerto. Si aparece una MAC pero el registro indica 0 found, compararla con las configuraciones locales. El problema original era un filtro exclusivo de UDP 9 que ignoraba los paquetes UDP 7.

## Recuperación manual

Elegir el directorio real de copia. Solo contiene archivos anteriores si existían antes de instalar. Detener el servicio, restaurar esos archivos, recargar systemd y recuperar el estado deseado:

```bash
systemctl stop pve-wakeonlan
# Sustituir BACKUP_DIR por el directorio real:
cp -a BACKUP_DIR/wol.sh /root/scripts/wol.sh
cp -a BACKUP_DIR/pve-wakeonlan.service /etc/systemd/system/pve-wakeonlan.service
systemctl daemon-reload
systemctl restart pve-wakeonlan
```

Consultar state.txt en la copia para ver el estado activo/habilitado anterior.

Método original: https://forum.proxmox.com/threads/wake-on-lan-wol-for-vms-and-containers.143879/
