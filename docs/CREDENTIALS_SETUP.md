# Configuração de credenciais — primeira execução

As integrações usam contas do próprio instalador. O repositório não contém credenciais prontas.

## 1. Ollama

Com o stack iniciado, o Ollama fica disponível entre containers em:

```text
http://ollama:11434
```

No n8n:

1. abra **Credentials**;
2. crie uma credencial **Ollama API**;
3. informe `http://ollama:11434`;
4. selecione-a em `Ollama · Modelo Executor` e `Ollama · Modelo Validador`.

O `ollama-init` baixa automaticamente os modelos definidos por `OLLAMA_MODEL` e `OLLAMA_VALIDATOR_MODEL`.

## 2. Gmail OAuth2

No n8n, conecte sua conta Gmail e atribua a mesma credencial aos nós:

- `ler_email`;
- `resumir_email`;
- `Solicitar aprovação · apagar_email`;
- `Gmail · Apagar Email`;
- `Solicitar aprovação · enviar_whatsapp`.

Use uma conta de teste para os primeiros ensaios de exclusão.

## 3. Google Calendar OAuth2

Crie/conecte uma credencial Google Calendar e selecione-a em `criar_evento`.

Primeiro teste recomendado: evento descartável com data e título inequívocos.

## 4. WhatsApp / WAHA

Abra:

```text
http://127.0.0.1:3000/dashboard
```

Use `WAHA_API_KEY`, `WAHA_DASHBOARD_USERNAME` e `WAHA_DASHBOARD_PASSWORD` do `.env`.

Depois:

1. crie/inicie a sessão `default`;
2. escaneie o QR Code com o WhatsApp de teste;
3. aguarde a sessão ficar operacional;
4. confirme que o webhook configurado pelo Compose aponta para o n8n.

## 5. E-mail de aprovação humana

Edite `.env`:

```env
APPROVAL_EMAIL=seu-email@gmail.com
```

Esse endereço recebe os links para retomar ou cancelar execuções pausadas nos nós `Wait`.

## Ordem segura de validação

1. `ler_email`;
2. `resumir_email`;
3. `criar_evento` com evento descartável;
4. `apagar_email` e **rejeitar**;
5. `enviar_whatsapp` e **rejeitar**;
6. confirmar que nenhum efeito ocorreu;
7. repetir com aprovação usando somente dados de teste;
8. ativar o workflow para o webhook do WhatsApp.

Consulte também [`QA_TEST_PLAN.md`](QA_TEST_PLAN.md).
