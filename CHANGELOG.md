# Changelog

## 1.0.0 — 2026-08-20

Primeira versão entregável do LeadFlow Local-First.

### Adicionado

- assistente FastAPI executado em Docker;
- integração bidirecional com WhatsApp via WAHA;
- execução de LLM local com Ollama;
- arquitetura com Agente Respondente + Agente Validador;
- pesquisa atual na internet via DDGS;
- memória curta persistente em SQLite;
- endpoint de pesquisa estruturada para automações;
- workflow n8n de 10 notícias diárias com envio por Gmail;
- workflow n8n de pesquisa sob demanda;
- workflow opcional de resumo diário por WhatsApp;
- inicializador e diagnóstico para Windows;
- inicializador para Linux/macOS;
- documentação de arquitetura, Gmail, requisitos e troubleshooting;
- testes unitários e GitHub Actions;
- Docker Compose com ordem de inicialização baseada em health checks;
- configuração segura por `.env` e geração automática de segredos no Windows.

### Privacidade e segurança

- nenhum segredo real versionado;
- allowlist opcional para chats;
- grupos desativados por padrão;
- credenciais Gmail configuradas somente no n8n local;
- fronteira de segurança e limites de implantação documentados.
