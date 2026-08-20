#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo 'Docker não encontrado. Instale Docker Engine/Desktop e tente novamente.' >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo 'Docker está instalado, mas o daemon não está em execução.' >&2
  exit 1
fi
if [[ ! -f .env ]]; then
  cp .env.example .env
  python3 - <<'PY'
from pathlib import Path
from secrets import token_hex
p=Path('.env')
s=p.read_text()
s=s.replace('CHANGE_ME_32_CHARS_OR_MORE', token_hex(32))
s=s.replace('CHANGE_ME_STRONG_PASSWORD', token_hex(20))
s=s.replace('CHANGE_ME_ANOTHER_LONG_RANDOM_SECRET', token_hex(32))
p.write_text(s)
PY
  echo 'Arquivo .env criado com segredos aleatórios. Edite GMAIL_REPORT_TO antes de ativar e-mails.'
fi

docker compose up -d --build
docker compose ps
cat <<'TXT'

LeadFlow iniciado.
WAHA:      http://localhost:3000/dashboard
n8n:       http://localhost:5678
API/docs:  http://localhost:8000/docs

Na primeira execução, conecte o WhatsApp no WAHA, crie o usuário local do n8n e importe os JSON de n8n/workflows/.
TXT
