# Plano de Testes — Sistema Agêntico n8n WhatsApp+Email

## Objetivo

Validar **instalação, configuração, comportamento funcional, segurança das ferramentas, Human-in-the-loop, rastreabilidade e qualidade das respostas** antes de ativar o workflow para uso real.

## Estratégia

O plano combina cinco níveis:

1. **validação estática** — JSON, contratos de tools, HTML do wizard, PowerShell e Docker Compose;
2. **smoke test de instalação** — containers reais, health checks, download Ollama, criação do proprietário, credenciais e importação do workflow;
3. **teste funcional** — chamada correta de cada ferramenta;
4. **teste de segurança** — ações críticas não podem contornar aprovação humana;
5. **teste ponta a ponta** — OAuth/WhatsApp reais do instalador, realizado somente com contas de teste ou do próprio usuário.

## Matriz — instalação e onboarding

| ID | Cenário | Pré-condição | Resultado esperado |
| --- | --- | --- | --- |
| SET-01 | primeira execução pelo `INICIAR_WINDOWS.bat` | `.setup-complete` ausente | abre o instalador visual em `127.0.0.1:8765` |
| SET-02 | Docker indisponível | Docker fechado | wizard retorna erro claro; nenhum sucesso falso é exibido |
| SET-03 | formulário de proprietário incompleto | primeira tela | instalação não inicia e informa o campo necessário |
| SET-04 | senha n8n fraca | menos de 8 chars, sem maiúscula ou número | validação bloqueia instalação |
| SET-05 | Google Client ID sem Secret | apenas um campo Google | validação solicita o par completo |
| SET-06 | instalação sem Google | campos Google vazios | núcleo instala normalmente; Google fica para depois |
| SET-07 | modelo Ollama ausente | volume novo | modelo é baixado e validado com `ollama show` |
| SET-08 | falha temporária no pull | internet instável | bootstrap tenta novamente até três vezes antes de falhar |
| SET-09 | primeiro proprietário n8n | instância nova | wizard cria proprietário pela API local e não grava senha no `.env` |
| SET-10 | credencial Ollama | proprietário existente | credencial é criada/importada e vinculada aos dois modelos |
| SET-11 | Google informado | Client ID/Secret válidos estruturalmente | Gmail/Calendar são preparados no n8n; consentimento continua pendente |
| SET-12 | importação de workflow | setup válido | workflow aparece uma vez no `list:workflow` |
| SET-13 | arquivos temporários | finalização concluída ou falha | `*.runtime.json` são removidos |
| SET-14 | segunda execução | `.setup-complete` presente | `INICIAR_WINDOWS.bat` sobe o stack sem reabrir onboarding |
| SET-15 | restos do antigo `ollama-init` | containers legados existentes | bootstrap remove conflito sem apagar volumes persistentes |

## Matriz — agente e integrações

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

## Automação no GitHub Actions

O CI deve provar, sem usar contas pessoais:

```text
checkout
  ↓
validação estática
  ↓
subir PostgreSQL + Ollama + n8n + WAHA
  ↓
ollama pull + ollama show
  ↓
validar estado inicial n8n
  ↓
criar proprietário de CI via /rest/owner/setup
  ↓
executar bootstrap -Mode Finalize
  ↓
importar credencial Ollama
  ↓
importar workflow
  ↓
list:workflow confirma o projeto
  ↓
arquivos temporários não existem mais
```

Esse teste cobre a parte reproduzível da primeira instalação sem exigir Google OAuth nem pareamento WhatsApp.

## Critérios de aprovação da release

Uma versão é considerada tecnicamente pronta quando:

- o CI da `main` está verde;
- a UI de instalação passa na validação estrutural;
- os scripts PowerShell não apresentam erro de parsing;
- Compose sobe os quatro serviços esperados;
- o caminho real de download Ollama funciona;
- proprietário de teste + importação de credencial + importação do workflow funcionam no smoke test;
- arquivos temporários são eliminados;
- os cinco contratos de ferramenta estão presentes;
- os dois fluxos críticos pausam em `Wait`;
- rejeição humana não causa efeito externo;
- aprovação humana causa exatamente um efeito esperado;
- o Agente QA recebe a resposta preliminar e gera a saída final;
- não há segredos reais no Git;
- restart do stack preserva configuração persistente do n8n/PostgreSQL.

## Teste final no Windows

Além do CI Linux, uma release de instalação deve ser exercitada em Windows 10/11 com Docker Desktop:

1. baixar ZIP em uma pasta nova;
2. executar `INSTALAR_WINDOWS.bat` como usuário comum;
3. preencher o formulário;
4. confirmar que o navegador acompanha a instalação;
5. fazer login no n8n com o acesso escolhido;
6. parear WhatsApp de teste;
7. autorizar uma conta Google de teste quando aplicável;
8. executar a matriz funcional acima.

## Evidências recomendadas

Para portfólio ou entrega técnica, capture somente dados sanitizados:

- primeira tela do wizard sem chaves reais;
- cards de instalação concluídos;
- canvas do n8n;
- execução de tool somente-leitura;
- execução em estado `Waiting`;
- caminho rejeitado;
- caminho aprovado usando conta/número de teste;
- GitHub Actions verde.

Nunca publique senha do n8n, Client Secret Google, QR Code do WhatsApp, tokens OAuth, API keys, conteúdo de e-mails privados ou telefones reais.
