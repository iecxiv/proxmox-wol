# proxmox-wol

Wake-on-LAN para arrancar máquinas virtuales y contenedores en un nodo Proxmox VE encendido. Incluye el script y la unidad systemd aportados por el usuario y confirmados como funcionales en su instalación, sin refactorizarlos.

## Funcionamiento

El script escucha en vmbr0, captura Ethernet WoL (0x0842) o UDP 7/9, extrae una MAC y busca una configuración coincidente, primero de VM y después de LXC. Si encuentra varias, utiliza la primera. Ejecuta qm start o pct start solo cuando interpreta el estado como stopped. Espera cinco segundos antes de cada captura; no está escuchando durante esa espera y un envío aislado puede perderse.

No enciende el servidor físico apagado ni instala nada dentro de los invitados. Debe ejecutarse en el host Proxmox.

Referencia del método: https://forum.proxmox.com/threads/wake-on-lan-wol-for-vms-and-containers.143879/

## Archivos

- wol.sh: script completo, con UDP 7 y 9 habilitados.
- pve-wakeonlan.service: servicio systemd.
- fix-wol-port.sh: parche para una instalación anterior que solo escuchaba UDP 9. No es necesario al instalar el wol.sh incluido.

## Instalación

Ejecutar como root en la shell del nodo Proxmox. Para clonar este repositorio privado se necesita acceso autenticado a GitHub; alternativamente, descargar los archivos desde una sesión autenticada y copiarlos al nodo.

```bash
apt update
apt install -y git tcpdump

git clone https://github.com/iecxiv/proxmox-wol.git
cd proxmox-wol
```

Revisar wol.sh y adaptar vmbr0 si corresponde. Comprobar interfaces:

```bash
ip -br link
```

Antes de sobrescribir una instalación existente, guardar copias:

```bash
STAMP=$(date +%Y%m%d-%H%M%S)
[ ! -f /root/scripts/wol.sh ] || cp -a /root/scripts/wol.sh "/root/scripts/wol.sh.bak.$STAMP"
[ ! -f /etc/systemd/system/pve-wakeonlan.service ] || cp -a /etc/systemd/system/pve-wakeonlan.service "/etc/systemd/system/pve-wakeonlan.service.bak.$STAMP"
```

Instalar y activar, desde el directorio del repositorio:

```bash
bash -n wol.sh && \
install -d -m 700 /root/scripts && \
install -m 700 wol.sh /root/scripts/wol.sh && \
install -m 644 pve-wakeonlan.service /etc/systemd/system/pve-wakeonlan.service && \
systemctl daemon-reload && \
systemctl enable pve-wakeonlan.service && \
systemctl restart pve-wakeonlan.service

systemctl status pve-wakeonlan.service --no-pager -l
```

## Prueba

Usar como objetivo la MAC configurada en la interfaz de la VM o LXC, no la MAC del host ni la de sus interfaces auxiliares. Consultar la configuración sustituyendo 123 por el ID real:

```bash
qm config 123
# Para un contenedor:
pct config 123
```

Con la máquina objetivo detenida, observar el registro y enviar WoL desde un dispositivo de la red. Configurar UDP 7 o 9 y la dirección broadcast correspondiente a la red. Repetir el envío si coincide con la espera de cinco segundos.

```bash
journalctl -fu pve-wakeonlan.service
```

En otra terminal, capturar mientras se envía el paquete:

```bash
tcpdump -ni vmbr0 -e -vv -XX '(ether proto 0x0842) or (udp port 7) or (udp port 9)'
```

## Diagnóstico y limitaciones

- En el caso probado, los paquetes llegaban por UDP 7 pero el filtro solo aceptaba UDP 9. Añadir UDP 7 solucionó el problema.
- Sin paquetes en la captura: revisar interfaz, puerto y envío del emisor.
- MAC capturada pero 0 found: comprobar que coincide con la configuración de la VM/LXC en este nodo.
- MAC vacía o incorrecta: revisar el analizador sed. Depende de una posición concreta de la salida hexadecimal de tcpdump; no valida completamente el paquete mágico.
- Esta versión conserva las expansiones sin comillas del original, incluida la MAC en grep; una MAC vacía no se gestiona de forma segura. Se conserva como versión funcional aportada, no como implementación endurecida.
- Los errores de tcpdump se ocultan mediante 2>/dev/null.
- Funciona con las configuraciones locales consultadas por el script; no implementa arranque remoto entre nodos del clúster.
- Se ejecuta como root y no autentica solicitudes WoL. Usar solo en una red de confianza; no exponerlo a Internet. La espera no es una protección completa contra abuso.

## Restauración manual

Sustituir los nombres por las copias reales creadas antes de instalar:

```bash
systemctl stop pve-wakeonlan.service
cp -a /root/scripts/wol.sh.bak.AAAAMMDD-HHMMSS /root/scripts/wol.sh
cp -a /etc/systemd/system/pve-wakeonlan.service.bak.AAAAMMDD-HHMMSS /etc/systemd/system/pve-wakeonlan.service
systemctl daemon-reload
systemctl restart pve-wakeonlan.service
```

## Desinstalación

Estos comandos eliminan el servicio y el script instalados, no las copias de seguridad ni el repositorio:

```bash
systemctl disable --now pve-wakeonlan.service
rm -f /etc/systemd/system/pve-wakeonlan.service
rm -f /root/scripts/wol.sh
systemctl daemon-reload
```
