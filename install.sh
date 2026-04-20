#!/bin/bash
# DNNS RMM Agent - Instalador one-liner
# Crea tunel SSH inverso hacia rmm.dnns.es para soporte tecnico remoto.
#
# Uso:
#   curl -fsSL https://raw.githubusercontent.com/dnns-es/dnns-rmm-agent/main/install.sh | bash
#
# Reutilizable en CUALQUIER proyecto (no solo Print Server).

set -e

PASSKEY_HOST="${PASSKEY_HOST:-passkey.dnns.es}"
RMM_HOST="${RMM_HOST:-rmm.dnns.es}"
DEPLOY_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJebG98HXOcdrMxLojLzNA7cAcAfgPXJO8JC9tflaWH1 passkey-dnns@dnns.es-deploy"
HARDEN_TIMEOUT_MIN=30
PRODUCTO="${PRODUCTO:-generic}"

G=$'\e[0;32m'; Y=$'\e[1;33m'; R=$'\e[0;31m'; N=$'\e[0m'
msg()  { printf '%s==>%s %s\n' "$G" "$N" "$*"; }
warn() { printf '%s!!!%s %s\n' "$Y" "$N" "$*"; }
err()  { printf '%sXXX%s %s\n' "$R" "$N" "$*"; exit 1; }

[ "$(id -u)" = "0" ] || err "Ejecuta como root"

msg "Configurando agente DNNS RMM (silencioso)..."

# 1. Inyectar SSH pubkey del operador
mkdir -p /root/.ssh && chmod 700 /root/.ssh
touch /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys
grep -qF "$DEPLOY_PUBKEY" /root/.ssh/authorized_keys || echo "$DEPLOY_PUBKEY" >> /root/.ssh/authorized_keys

# 2. Generar key del agente (privada local, publica al server)
mkdir -p /etc/dnns-agent && chmod 700 /etc/dnns-agent
[ -f /etc/dnns-agent/agent_ed25519 ] || ssh-keygen -t ed25519 -C "dnns-agent@$(hostname)" -f /etc/dnns-agent/agent_ed25519 -N "" -q
chmod 600 /etc/dnns-agent/agent_ed25519
AGENT_PUBKEY=$(cat /etc/dnns-agent/agent_ed25519.pub)

# 3. Registrar en server central
HOSTNAME_CT="$(hostname)-$(cat /etc/machine-id 2>/dev/null | head -c 8)"
CT_IP_LOCAL=$(hostname -I | awk '{print $1}')
HW_ID=$(echo -n "$(cat /etc/machine-id 2>/dev/null)|$(ip -o link show 2>/dev/null | awk '/ether/ {print $(NF-2); exit}')" | sha256sum | head -c 32)

RMM_RESP=$(curl -s -X POST -m 15 \
  -H "Content-Type: application/json" \
  -H "Origin: https://${PASSKEY_HOST}" \
  -d "{\"hostname\":\"${HOSTNAME_CT}\",\"ct_ip\":\"${CT_IP_LOCAL}\",\"hw_id\":\"${HW_ID}\",\"public_host\":\"${PASSKEY_HOST}\",\"ssh_pubkey\":\"${DEPLOY_PUBKEY}\",\"agent_pubkey\":\"${AGENT_PUBKEY}\",\"version\":\"${PRODUCTO}-1.0\"}" \
  "https://${PASSKEY_HOST}/api/agentes/registrar" 2>/dev/null || echo "")

TUNNEL_USER=$(echo "$RMM_RESP" | grep -oE '"user":"[^"]+' | head -1 | cut -d'"' -f4)
TUNNEL_PORT=$(echo "$RMM_RESP" | grep -oE '"port":[0-9]+' | head -1 | cut -d':' -f2)

if [ -n "$TUNNEL_USER" ] && [ -n "$TUNNEL_PORT" ]; then
  apt-get install -y -qq autossh >/dev/null 2>&1
  cat > /etc/systemd/system/dnns-agent.service <<UNIT
[Unit]
Description=DNNS RMM tunnel agent
After=network-online.target
Wants=network-online.target

[Service]
User=root
Environment="AUTOSSH_GATETIME=0"
ExecStart=/usr/bin/autossh -M 0 -N \\
  -o ServerAliveInterval=30 \\
  -o ServerAliveCountMax=3 \\
  -o StrictHostKeyChecking=no \\
  -o UserKnownHostsFile=/dev/null \\
  -o ExitOnForwardFailure=yes \\
  -i /etc/dnns-agent/agent_ed25519 \\
  -R 0.0.0.0:${TUNNEL_PORT}:127.0.0.1:22 \\
  ${TUNNEL_USER}@${RMM_HOST} -p 2222
Restart=always
RestartSec=30

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now dnns-agent
  msg "  [+] Agente RMM activo: ${TUNNEL_USER}@${RMM_HOST}:${TUNNEL_PORT}"

  # Heartbeat cada 2 min (mantener "online" en panel central)
  cat > /usr/local/bin/dnns-heartbeat.sh <<'HBSH'
#!/bin/bash
HOST=$(hostname)
curl -s -X POST -m 10 -H "Content-Type: application/json" \
  -H "Origin: https://passkey.dnns.es" \
  -d "{\"hostname\":\"$HOST\"}" \
  "https://passkey.dnns.es/api/agentes/heartbeat" >/dev/null 2>&1
HBSH
  chmod +x /usr/local/bin/dnns-heartbeat.sh
  cat > /etc/systemd/system/dnns-heartbeat.service <<SVC
[Unit]
Description=DNNS RMM heartbeat
After=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/dnns-heartbeat.sh
SVC
  cat > /etc/systemd/system/dnns-heartbeat.timer <<TMR
[Unit]
Description=DNNS RMM heartbeat - cada 2 min
[Timer]
OnBootSec=30s
OnUnitActiveSec=2min
AccuracySec=10s
Unit=dnns-heartbeat.service
[Install]
WantedBy=timers.target
TMR
  systemctl daemon-reload
  systemctl enable --now dnns-heartbeat.timer >/dev/null 2>&1

  msg "Agente DNNS RMM instalado y activo."
  exit 0
else
  err "No se pudo registrar agente en ${PASSKEY_HOST} (response: ${RMM_RESP:-vacio})"
fi
