# Instalação e primeira execução

## Requisitos

- Windows 10/11 64-bit;
- Docker Desktop com Docker Compose v2;
- 8 GB de RAM mínimo; 16 GB recomendado;
- aproximadamente 10 GB livres;
- internet na primeira instalação.

Não é necessário instalar manualmente Python, Node.js, PostgreSQL, n8n, Ollama ou WAHA.

## Instalação recomendada

1. Baixe ou clone o repositório.
2. Abra o Docker Desktop e aguarde o engine ficar pronto.
3. Execute `INSTALAR_WINDOWS.bat`.
4. O assistente local abrirá em `http://127.0.0.1:8765`.
5. Informe nome, e-mail/senha locais do n8n, modelos Ollama e, opcionalmente, Google OAuth.
6. Clique em **Instalar e configurar automaticamente**.

O instalador:

```text
verifica Docker
  ↓
cria/repara .env
  ↓
gera segredos internos
  ↓
valida Docker Compose
  ↓
sobe PostgreSQL + Ollama
  ↓
verifica/baixa modelo
  ↓
sobe n8n + WAHA
  ↓
cria owner local do n8n
  ↓
cria credencial Ollama
  ↓
prepara Google OAuth quando informado
  ↓
importa e valida workflow
  ↓
remove temporários
  ↓
cria .setup-complete
```

Nas execuções seguintes, `INICIAR_WINDOWS.bat` apenas sobe o stack já configurado.

## Consentimentos que continuam manuais

A automação não tenta contornar consentimentos de identidade:

- Google: o usuário conclui OAuth;
- WhatsApp: o usuário escaneia o QR Code;
- ações destrutivas/comunicação externa: aprovação humana ocorre durante a execução.

## UTF-8 no Windows

O servidor local do instalador lê `setup/app.html` e arquivos de configuração explicitamente como UTF-8 e responde com `charset=utf-8`. O CI possui regressões específicas para evitar textos corrompidos por diferenças de encoding do Windows PowerShell 5.1.

## Diagnóstico

Execute:

```text
DIAGNOSTICO_WINDOWS.bat
```

O script verifica Docker, Compose, containers, endpoints e logs dos serviços.

## Desenvolvimento manual

Arquivos centrais:

- `docker-compose.yml`: infraestrutura;
- `n8n-agent-workflow.json`: fluxo principal;
- `scripts/bootstrap.ps1`: bootstrap e reparo;
- `scripts/setup-wizard-v2.ps1`: servidor local do instalador;
- `setup/app.html`: interface de setup;
- `.env.example`: contrato de configuração.

## Segurança

Consulte [`../SECURITY.md`](../SECURITY.md). Segredos reais não devem ser commitados. As interfaces administrativas são ligadas a `127.0.0.1` e os arquivos temporários de credenciais são removidos ao final do setup.
