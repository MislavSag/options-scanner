#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run as root (use: sudo bash azure/setup_ib_gateway_docker.sh)"
  exit 1
fi

APP_DIR="${APP_DIR:-/opt/options-scanner}"
STACK_DIR="${STACK_DIR:-/opt/ib-gateway}"
CALLER_USER="${SUDO_USER:-azureuser}"

if [[ ! -d "${APP_DIR}" ]]; then
  echo "App dir not found: ${APP_DIR}"
  exit 1
fi

apt-get update
apt-get install -y docker.io docker-compose-plugin

systemctl enable --now docker

mkdir -p "${STACK_DIR}"
cp "${APP_DIR}/azure/ib-gateway/docker-compose.yml" "${STACK_DIR}/docker-compose.yml"

if [[ ! -f "${STACK_DIR}/.env" ]]; then
  cp "${APP_DIR}/azure/ib-gateway/.env.example" "${STACK_DIR}/.env"
  echo "Created ${STACK_DIR}/.env from template."
  echo "Edit it now and set real TWS_USERID/TWS_PASSWORD."
fi

cat >/etc/systemd/system/ib-gateway-docker.service <<EOF
[Unit]
Description=IB Gateway (Docker + IBC)
After=network-online.target docker.service
Wants=network-online.target
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${STACK_DIR}
ExecStart=/usr/bin/docker compose --env-file ${STACK_DIR}/.env -f ${STACK_DIR}/docker-compose.yml up -d
ExecStop=/usr/bin/docker compose --env-file ${STACK_DIR}/.env -f ${STACK_DIR}/docker-compose.yml down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ib-gateway-docker.service
usermod -aG docker "${CALLER_USER}" || true

echo
echo "Next steps:"
echo "1) sudo nano ${STACK_DIR}/.env"
echo "2) sudo systemctl start ib-gateway-docker.service"
echo "3) sudo systemctl status ib-gateway-docker.service --no-pager"
echo "4) ss -ltnp | grep -E '4001|4002'"
echo
echo "If using paper account, keep config.yaml tws.port=4002"
