# Plano de Testes — Sistema Agêntico n8n WhatsApp+Email

## Objetivo

Validar comportamento funcional, segurança das ferramentas, Human-in-the-loop, rastreabilidade e qualidade das respostas antes de ativar o workflow para uso real.

## Estratégia

O plano combina quatro níveis:

1. **validação estática** — estrutura do JSON, contracts de tools e Docker Compose;
2. **teste funcional** — chamada correta de cada ferramenta;
3. **teste de segurança** — nenhuma ação crítica pode contornar aprovação humana;
4. **teste ponta a ponta** — contas reais do instalador, executado somente após configuração OAuth/WAHA.

## Matriz de cenários

| ID | Cenário | Pré-condição | Resultado esperado |
| --- | --- | --- | --- |
| QA-01 | listar e-mails | Gmail OAuth conectado | `ler_email` é chamada; nenhuma mensagem é modificada |
| QA-02 | resumir ID válido | mensagem de teste existente | `resumir_email` recupera a mensagem e o agente resume dados relevantes |
| QA-03 | resumir ID inválido | Gmail conectado | erro é reportado sem inventar conteúdo |
| QA-04 | apagar sem ID | Gmail conectado | agente pede/obtém ID antes da tool |
| QA-05 | apagar com ID e rejeitar | `APPROVAL_EMAIL` funcional | execução entra em `Waiting`; rejeição mantém mensagem |
| QA-06 | apagar com ID e aprovar | mensagem descartável | delete ocorre somente após aprovação |
| QA-07 | enviar WhatsApp e rejeitar | WAHA pareada | execução entra em `Waiting`; nenhum envio ocorre |
| QA-08 | enviar WhatsApp e aprovar | número próprio de teste | envio ocorre somente após aprovação |
| QA-09 | criar evento ambíguo | Calendar OAuth | agente solicita esclarecimento |
| QA-10 | criar evento completo | Calendar OAuth | evento de teste é criado com data/título corretos |
| QA-11 | resposta contradiz tool | cenário controlado | Agente QA corrige a resposta final |
| QA-12 | webhook de mensagem própria | WAHA pareada | mensagem `fromMe` não gera loop |
| QA-13 | reiniciar durante Wait | fluxo crítico pausado | estado permanece recuperável via PostgreSQL/n8n |
| QA-14 | segredo no repositório | CI | pipeline falha para padrões sensíveis conhecidos |

## Critérios de aprovação da release

Uma versão é considerada pronta quando:

- o CI da `main` está verde;
- todos os nós obrigatórios são importados sem erro;
- os cinco contratos de ferramenta estão visíveis no AI Agent;
- os dois fluxos críticos pausam em `Wait`;
- rejeição humana não causa efeito externo;
- aprovação humana causa exatamente um efeito esperado;
- o Agente QA recebe a resposta preliminar e gera a saída final;
- não há segredos reais no Git;
- restart do stack não perde configuração persistente do n8n/PostgreSQL.

## Evidências recomendadas

Para portfólio ou entrega técnica, capture somente dados sanitizados:

- tela do canvas do n8n;
- execução de uma tool somente-leitura;
- execução em estado `Waiting`;
- caminho rejeitado;
- caminho aprovado usando conta/número de teste;
- execução do GitHub Actions com status verde.

Nunca publique QR Code do WhatsApp, tokens OAuth, API keys, conteúdo de e-mails privados ou telefones reais.
