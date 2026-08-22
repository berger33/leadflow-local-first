# Changelog

## 2.2.0 — 2026-08-22

Release focada em **experiência de instalação e configuração para novos usuários**.

### Instalador visual

- novo `INSTALAR_WINDOWS.bat` como ponto de entrada recomendado;
- nova interface local profissional em `setup/index.html`;
- wizard servido somente em `127.0.0.1:8765`;
- layout responsivo em quatro etapas: Preferências → Instalação → Conexões → Pronto;
- status visual para Docker, PostgreSQL, Ollama, n8n, WAHA e workflow;
- barra de progresso, mensagens de estado, toasts e painel de diagnóstico técnico;
- `INICIAR_WINDOWS.bat` detecta automaticamente primeira execução e redireciona para o wizard.

### Configuração em uma única tela

- criação do proprietário local do n8n a partir de nome, sobrenome, e-mail e senha escolhidos no assistente;
- senha do proprietário mantida somente em memória durante o setup;
- escolha do modelo executor e do modelo validador;
- configuração de fuso horário;
- e-mail para aprovações Human-in-the-loop;
- campos opcionais para Google OAuth Client ID e Client Secret;
- URI de callback Google exibida e copiável na interface.

### Automação de credenciais

- credencial Ollama criada automaticamente no n8n;
- credencial Ollama vinculada aos dois nós de modelo durante a importação;
- quando Google Client ID/Secret são fornecidos, o bootstrap prepara credenciais Gmail e Google Calendar;
- workflow é gerado temporariamente com referências explícitas às credenciais;
- arquivos `credentials.runtime.json` e `workflow.runtime.json` são ignorados pelo Git e removidos após a finalização;
- consentimento Google continua intencionalmente dependente do usuário;
- usuário e senha WAHA são gerados automaticamente e exibidos somente no ambiente local.

### Bootstrap

- modos separados `Prepare`, `Finalize`, `Start` e `Full`;
- caminhos de arquivos temporários compatíveis entre Windows PowerShell e PowerShell Core;
- instalação retomável e idempotente;
- `.setup-complete` diferencia primeira instalação de inicializações futuras;
- health checks continuam bloqueando avanço quando n8n, WAHA, PostgreSQL ou Ollama não estão realmente disponíveis.

### CI / QA

- validação estrutural da UI de setup;
- validação de sintaxe dos dois scripts PowerShell;
- contrato de endpoints do wizard;
- smoke test Docker com PostgreSQL, Ollama, n8n e WAHA;
- `ollama pull` real de modelo pequeno;
- criação de proprietário de teste pelo endpoint local do n8n;
- execução da fase `Finalize` no CI;
- verificação de importação do workflow e limpeza dos arquivos temporários.

## 2.1.0 — 2026-08-22

Release focada em **confiabilidade da primeira execução no Windows**.

### Corrigido

- removido o serviço temporário `ollama-init`, que podia deixar o Compose com dependência quebrada e gerar `No such container`;
- n8n não depende mais da conclusão de um container descartável;
- removidos `container_name` fixos para reduzir conflitos entre downloads/pastas diferentes;
- definido nome de projeto Compose estável (`sistema-agentico`);
- volumes receberam nomes estáveis para persistência previsível;
- script de importação deixou de tentar iniciar uma stack quebrada de forma independente;
- bootstrap passou a detectar instalação nova do n8n antes da importação;
- removida ambiguidade de passagem do argumento `-d` entre versões do PowerShell.

### Bootstrap inteligente

- novo `scripts/bootstrap.ps1`;
- geração automática de segredos locais ausentes;
- reparo de containers legados conhecidos sem apagar volumes;
- inicialização em etapas: PostgreSQL/Ollama antes de n8n/WAHA;
- health checks reais antes de avançar;
- verificação do modelo Ollama antes do download;
- até três tentativas de download do modelo;
- importação idempotente do workflow para evitar duplicatas;
- diagnóstico final e mensagens de erro direcionadas.

### CI

- validação de sintaxe do bootstrap PowerShell;
- regressão que impede o retorno de `ollama-init` ao Compose;
- smoke test Docker real;
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
- diagnóstico Windows alinhado aos novos serviços;
- demo pública refeita para Function Calling + Human-in-the-loop;
- README reestruturado para portfólio de Automação, IA e QA.

## 1.0.0 — 2026-08-20

Primeira versão entregável do LeadFlow Local-First, com FastAPI, Ollama, WAHA, pesquisa web, dual-agent e automações n8n. Essa arquitetura foi a base evolutiva da versão 2.0.
