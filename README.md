# DNNS RMM Agent

> Agente de mantenimiento remoto via túnel SSH inverso. Reutilizable en cualquier servidor o proyecto DNNS.

[![Licencia](https://img.shields.io/badge/licencia-gratuita-blue)]()

## 💚 Software gratuito y sin ánimo de lucro

Servicio de soporte técnico remoto **gratuito** para servidores que ejecutan software DNNS o que desean asistencia de mantenimiento remoto.

---

## ¿Qué hace?

Crea un **túnel SSH inverso** seguro desde tu servidor hacia el **server RMM que tú elijas** (puede ser el tuyo propio con [`dnns-rmm-server`](https://github.com/dnns-es/dnns-rmm-server) o el oficial DNNS), de forma que el operador autorizado de ese server pueda conectarse para:

- Mantenimiento y actualizaciones
- Resolución de problemas
- Configuración avanzada
- Monitorización del estado del sistema

**Es OPT-IN**: solo se instala si tú lo decides explícitamente. **Tú eliges el server destino** durante la instalación (interactivo) o vía variables de entorno.

---

## Instalación

**Modo interactivo** (te pregunta a qué server conectar):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dnns-es/dnns-rmm-agent/main/install.sh)
```

**Modo automatizado** (apuntando a tu propio server RMM):

```bash
RMM_HOST=ejemplo.dnns.es \
PASSKEY_HOST=ejemplo.dnns.es \
bash <(curl -fsSL https://raw.githubusercontent.com/dnns-es/dnns-rmm-agent/main/install.sh)
```

Sólo Debian/Ubuntu como root.

---

## ¿Cómo funciona?

```
┌──────────────────┐  SSH inverso  ┌─────────────────────┐
│ Tu servidor      │ ──tunel R─►   │ Server RMM elegido  │
│ (donde instalas) │               │ (rmm.miempresa.com  │
│ autossh + key    │◄─SSH ops──────│  o rmm.dnns.es...)  │
└──────────────────┘               └─────────────────────┘
```

1. El instalador te pregunta qué dominio/host usar (o lo coge de env vars)
2. Genera una clave SSH propia del agente (privada queda local)
3. Se registra en el server elegido (`PASSKEY_HOST/api/agentes/registrar`) con hostname + hw_id + admin email + dominio
4. Recibe un puerto reservado en `RMM_HOST:2222`
5. Lanza `autossh` como servicio `systemd` con `-R puerto:127.0.0.1:22`
6. El operador del server destino conecta a `127.0.0.1:puerto` y entra a tu servidor

---

## Privacidad y seguridad

- ✅ **Tú eliges el server destino**. Si montas tu propio [`dnns-rmm-server`](https://github.com/dnns-es/dnns-rmm-server) nadie de fuera tiene acceso.
- ✅ La clave privada del agente **nunca sale** de tu servidor.
- ✅ La clave del operador del server destino (pública) se inyecta en `/root/.ssh/authorized_keys` solo para ese operador autorizado.
- ✅ El túnel sólo permite SSH al servidor (no expone otros servicios).
- ✅ Puedes cortar el acceso en cualquier momento: `systemctl stop dnns-agent && systemctl disable dnns-agent`.
- ✅ Logs en `journalctl -u dnns-agent -u dnns-heartbeat`.

---

## Desinstalación

```bash
systemctl disable --now dnns-agent dnns-heartbeat.timer
rm -rf /etc/dnns-agent
rm -f /etc/systemd/system/dnns-agent.service
rm -f /etc/systemd/system/dnns-heartbeat.service
rm -f /etc/systemd/system/dnns-heartbeat.timer
rm -f /usr/local/bin/dnns-heartbeat.sh
# Quitar la clave SSH del operador del server RMM:
sed -i '/dnns.es-deploy/d' /root/.ssh/authorized_keys
systemctl daemon-reload
```

---

## Requisitos

- Debian 11+ / Ubuntu 22.04+
- root
- Salida HTTPS hacia el server elegido
- Salida SSH (TCP 2222) hacia el server elegido
- `autossh` (lo instala el script)

---

## Configurar a qué server conectar

**Opción A — interactivo:** simplemente ejecutas el instalador y te pregunta el dominio del server al que conectar.

**Opción B — variables de entorno** (útil para automatización o instalaciones desatendidas):

```bash
PASSKEY_HOST=ejemplo.dnns.es \
RMM_HOST=ejemplo.dnns.es \
DOMINIO_SERVER=mi-print.dnns.es \
ADMIN_EMAIL=admin@ejemplo.es \
PRODUCTO=printserver \
bash <(curl -fsSL https://raw.githubusercontent.com/dnns-es/dnns-rmm-agent/main/install.sh)
```

## Variables de entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `PASSKEY_HOST` | `rmm.dnns.es` | Host de la API de registro (HTTPS) |
| `RMM_HOST` | `rmm.dnns.es` | Host del sshd:2222 (donde llega el túnel) |
| `PRODUCTO` | `generic` | Identificador del producto/instalación |
| `ADMIN_EMAIL` | (vacío) | Email del admin del server (reportado al RMM) |
| `ADMIN_NAME` | (vacío) | Nombre del admin |
| `DOMINIO_SERVER` | (vacío) | Dominio público del server (reportado al RMM) |

---

## Licencia

Gratuita, sin ánimo de lucro. Ver [LICENSE](LICENSE).

---

## Soporte

Email: `info@dnns.es`
