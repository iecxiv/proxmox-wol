# proxmox-wol

Snippet para añadir UDP 7 al filtro de un script Wake-on-LAN para máquinas virtuales y contenedores Proxmox VE.

## Problema resuelto

En la instalación donde se probó, el servicio estaba activo y escuchaba en vmbr0, pero su filtro solo aceptaba Ethernet WoL (0x0842) o UDP 9. Los paquetes llegaban por UDP 7. Añadir ese puerto resolvió el problema.

## Requisitos

Este repositorio no instala una solución WoL completa: modifica una instalación existente. Se espera el script /root/scripts/wol.sh y el servicio pve-wakeonlan.service, con un filtro que contenga udp port 9. Ejecutar como root en el nodo Proxmox, que debe permanecer encendido. Revisar el script antes de ejecutarlo.

Tutorial de referencia: https://forum.proxmox.com/threads/wake-on-lan-wol-for-vms-and-containers.143879/

## Uso

Desde el directorio del repositorio:

```bash
bash fix-wol-port.sh
```

El snippet guarda una copia con fecha, añade UDP 7 manteniendo UDP 9, comprueba la sintaxis y reinicia el servicio. Si detecta la cadena udp port 7, no modifica el filtro. La comprobación es textual: para scripts con varios filtros o un formato diferente, revisar y adaptar manualmente. La copia permite recuperación manual; no hay rollback automático.

## Diagnóstico

```bash
journalctl -fu pve-wakeonlan
```

En otra terminal, mientras se envía el WoL:

```bash
tcpdump -ni vmbr0 -e -vv -XX '(ether proto 0x0842) or (udp port 7) or (udp port 9)'
```

Si se captura una MAC pero el registro indica 0 found, comprobar que la MAC objetivo coincide con la configurada en la VM o LXC. Este parche solo corrige el filtro de puertos, no el analizador de paquetes ni la búsqueda de máquinas.

## Restauración manual

Sustituir la ruta del ejemplo por la copia indicada durante la ejecución:

```bash
cp -a /root/scripts/wol.sh.bak.AAAAMMDD-HHMMSS /root/scripts/wol.sh
systemctl restart pve-wakeonlan
```
