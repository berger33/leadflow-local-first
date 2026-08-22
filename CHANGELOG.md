# Changelog

## 2.1.0 — 2026-08-22

Release focada em **confiabilidade da primeira execução no Windows**.

### Corrigido

- removido o serviço temporário `ollama-init`, que podia deixar o Compose com dependência quebrada e gerar `No such container`;
- n8n não depende mais da conclusão de um container descartável;
- removidos `container_name` fixos para reduzir conflitos entre downloads/pastas diferentes;
- definido nome de projeto Compose estável (`sistema-agentico`);
- volumes receberam nomes estáveis para persistência previsível;
- script de importação deixou de tentar iniciar uma stack quebrada de forma independente.

### Bootstrap inteligente

- novo `scripts/bootstrap.ps1`;
- geração automática de segredos locais ausentes;
- reparo de containers legados conhecidos sem apagar volumes;
- inicialização em etapas: PostgreSQL/Ollama antes de n8n/WAHA;
- health checks reais antes de avançar;
- verificação do modelo Ollama antes do download;
- até três tentativas de download do modelo;
- importação idempotente do workflow para evitar duplicatas;
- solicitação do e-mail de aprovação somente quando ainda não configurado;
- diagnóstico final e mensagens de erro direcionadas.

### CI

- validação de sintaxe do bootstrap PowerShell;
- regressão que impede o retorno de `ollama-init` ao Compose;
- smoke test Docker real de PostgreSQL, Ollama e n8n;
- verificação da API/CLI do Ollama e `/healthz` do n8n.

## 2.0.0 — 2026-08-21

Evolução do **LeadFlow Local-First** para o **Sistema Agêntico n8n WhatsApp+Email**.

### Arquitetura

- n8n passa a ser o orquestrador central do sistema;
- Advanced AI Agent com Function Calling;
- LLM local via Ollama;
- segundo Agente QA Validador sem acesso a ferramentas;
- PostgreSQL para estado e histórico do n8n;
- WAHA para entrada/saída WhatsApp;
- Gmail e Google Calendar como ferramentas do agente.

### Ferramentas

- `ler_email(query, limit)`;
- `resumir_email(id)`;
- `apagar_email(id)`;
- `enviar_whatsapp(contato, msg)`;
- `criar_evento(data, titulo)`.

### Segurança e qualidade

- `apagar_email` e `enviar_whatsapp` executam como subworkflows controlados;
- solicitação de aprovação humana por e-mail;
- nós `Wait` antes do efeito destrutivo/externo;
- caminhos explícitos de aprovação e rejeição;
- audit trail de input, tool calls, argumentos, resultados e output;
- nenhum raw chain-of-thought persistido;
- interfaces administrativas vinculadas a `127.0.0.1`;
- CI para validar contratos agênticos, workflow JSON, Compose e regressões básicas de segurança.

### Experiência de entrega

- novo `n8n-agent-workflow.json` importável;
- `INICIAR_WINDOWS.bat` atualizado para subir o stack e importar o workflow;
- diagnóstico Windows alinhado aos novos serviços;
- demo pública refeita para Function Calling + Human-in-the-loop;
- README reestruturado para portfólio de Automação, IA e QA.

## 1.0.0 — 2026-08-20

Primeira versão entregável do LeadFlow Local-First, com FastAPI, Ollama, WAHA, pesquisa web, dual-agent e automações n8n. Essa arquitetura foi a base evolutiva da versão 2.0.
