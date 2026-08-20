# Arquitetura do LeadFlow Local-First

## Visão geral

```text
                         INTERNET
                            ^
                            |
                    DDGS / metabuscadores
                            |
                            v
WhatsApp <-> WAHA <-> FastAPI Assistant <-> Ollama local
                       |        |             |      |
                       |        |             |      +-- Agente 2: Validador
                       |        |             +--------- Agente 1: Respondente
                       |        |
                       |        +-- SQLite: memória curta por conversa
                       |
                       +<------------- n8n ------------> Gmail
                                      |
                                      +-- agenda pesquisas
                                      +-- recebe relatórios estruturados
                                      +-- envia e-mail
                                      +-- pode enviar resumo pelo WAHA
```

## Fluxo de conversa no WhatsApp

1. A WAHA mantém a sessão do WhatsApp e envia o evento `message` para `POST /webhooks/waha`.
2. O Assistente ignora mensagens próprias, grupos se desabilitados e chats fora da allowlist.
3. O roteamento identifica se a pergunta depende de informação recente.
4. Se necessário, o serviço de busca coleta contexto da internet.
5. **Agente 1** responde usando histórico local da conversa e, quando aplicável, fontes web.
6. **Agente 2** recebe pergunta original, resposta do Agente 1 e fontes disponíveis.
7. O Validador avalia entendimento, aderência, factualidade e cobertura. Se necessário, fornece uma resposta corrigida.
8. A resposta final é armazenada no SQLite e enviada de volta pelo WAHA.

## Fluxo de pesquisa programada

1. O Schedule Trigger do n8n dispara no horário configurado.
2. O n8n chama `POST /research` no Assistente.
3. O Assistente coleta notícias na internet.
4. O Agente 1 gera o relatório.
5. O Agente 2 valida o relatório e corrige desvios.
6. A API retorna texto, HTML, fontes e resumo curto.
7. O node Gmail envia o HTML para `GMAIL_REPORT_TO`.
8. Opcionalmente outro workflow envia o resumo ao WhatsApp.

## Componentes

### `assistant`
FastAPI em Python. Contém a lógica de conversa, pesquisa, memória, dual-agent e endpoints usados pelo n8n.

### `ollama`
Runtime da LLM local. Os prompts de conversa não precisam ser enviados para uma API de LLM externa.

### `waha`
Integra o WhatsApp por HTTP/webhooks. A porta deve permanecer restrita ao computador/rede confiável.

### `n8n`
Responsável por agenda, orquestração e integrações externas, incluindo Gmail.

### Persistência

- Ollama: volume dos modelos.
- WAHA: volume da sessão do WhatsApp.
- n8n: credenciais, workflows e execuções no volume próprio.
- Assistente: SQLite para memória curta de conversa.

## Modelo de segurança

- segredos somente no `.env`, ignorado pelo Git;
- API key obrigatória no WAHA;
- senha própria no dashboard WAHA;
- chave de criptografia fixa para preservar credenciais do n8n após reinícios;
- allowlist opcional de chats do WhatsApp;
- grupos desabilitados por padrão;
- validação por segundo agente;
- nenhuma credencial Gmail versionada;
- portas pensadas para `localhost`, não para exposição direta na internet.
