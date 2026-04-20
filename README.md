# DNNS RMM Agent

> Agente de mantenimiento remoto via túnel SSH inverso. Reutilizable en cualquier servidor o proyecto DNNS.

[![Licencia](https://img.shields.io/badge/licencia-gratuita-blue)]()

## 💚 Software gratuito y sin ánimo de lucro

Servicio de soporte técnico remoto **gratuito** para servidores que ejecutan software DNNS o que desean asistencia de mantenimiento remoto.

---

## ¿Qué hace?

Crea un **túnel SSH inverso** seguro desde tu servidor hacia `rmm.dnns.es`, de forma que el operador autorizado de DNNS pueda conectarse para:

- Mantenimiento y actualizaciones
- Resolución de problemas
- Configuración avanzada
- Monitorización del estado del sistema

**Es OPT-IN**: solo se instala si tú lo decides explícitamente.

---

## Instalación

```bash
curl -fsSL https://raw.githubusercontent.com/dnns-es/dnns-rmm-agent/main/install.sh | bash
```

Sólo Debian/Ubuntu como root.

---

## ¿Cómo funciona?

```
┌──────────────────┐  SSH inverso  ┌────────────────┐
│ Tu servidor      │ ──tunel R─►   │ rmm.dnns.es    │
│ (donde instalas) │               │ (servidor DNNS)│
│ autossh + key    │◄─SSH ops──────│                │
└──────────────────┘               └────────────────┘
```

1. El instalador genera una clave SSH propia del agente
2. Se registra en `passkey.dnns.es` con su hostname + hardware ID
3. Recibe un puerto reservado en `rmm.dnns.es`
4. Lanza `autossh` como servicio `systemd` con `-R puerto:127.0.0.1:22`
5. El operador de DNNS conecta a `rmm.dnns.es:puerto` para llegar a tu servidor

---

## Privacidad y seguridad

- ✅ La clave privada del agente **nunca sale** de tu servidor.
- ✅ La clave del operador (pública) se inyecta en `/root/.ssh/authorized_keys` solo para el operador autorizado.
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
# Quitar la clave SSH del operador:
sed -i '/passkey-dnns@dnns.es-deploy/d' /root/.ssh/authorized_keys
systemctl daemon-reload
```

---

## Requisitos

- Debian 11+ / Ubuntu 22.04+
- root
- Salida HTTPS hacia `passkey.dnns.es`
- Salida SSH (TCP 2222) hacia `rmm.dnns.es`
- `autossh` (lo instala el script)

---

## Variables de entorno opcionales

| Variable | Default | Descripción |
|----------|---------|-------------|
| `PASSKEY_HOST` | `passkey.dnns.es` | Servidor central de registro |
| `RMM_HOST` | `rmm.dnns.es` | Servidor del túnel SSH |
| `PRODUCTO` | `generic` | Identificador del producto/instalación |

---

## Licencia

Gratuita, sin ánimo de lucro. Ver [LICENSE](LICENSE).

---

## Soporte

Email: `info@dnns.es`
