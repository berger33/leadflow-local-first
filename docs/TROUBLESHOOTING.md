# Troubleshooting

## `docker compose up` falha

Abra o Docker Desktop e confirme que o engine está ativo. Rode:

```bash
docker compose config
docker compose up -d --build
docker compose logs --tail=100
```

## O modelo ainda não responde

Na primeira execução o `ollama-init` baixa o modelo. Dependendo da conexão, isso pode levar vários minutos.

```bash
docker compose logs ollama-init
docker compose exec ollama ollama list
```

Se necessário:

```bash
docker compose exec ollama ollama pull qwen3:4b
```

## WhatsApp não recebe respostas

1. Abra `http://localhost:3000/dashboard`.
2. Confirme que a sessão `default` está operacional.
3. Verifique se o QR Code foi pareado.
4. Confira os logs:

```bash
docker compose logs --tail=100 waha
docker compose logs --tail=100 assistant
```

Se `WHATSAPP_ALLOWED_CHAT_IDS` estiver preenchido, o ID do chat precisa estar nessa lista.

## O relatório não chega por e-mail

O Gmail exige uma credencial conectada dentro do n8n. Consulte `docs/GMAIL_N8N.md`.

Também confira:

- `GMAIL_REPORT_TO` no `.env`;
- se o workflow está ativo;
- a aba **Executions** no n8n;
- se o node Gmail está com credencial selecionada.

## Pesquisa web retorna erro

A pesquisa usa metabuscadores públicos por meio do DDGS e pode sofrer rate limit temporário. Aguarde alguns minutos e tente novamente. A conversa sem web continua disponível.

## Resetar somente a memória de conversa

```bash
docker compose down
docker volume rm leadflow-local-first_assistant_data
```

## Reset total

**Atenção:** remove modelo baixado, sessão WhatsApp, credenciais/workflows n8n e memória.

```bash
docker compose down -v
```
