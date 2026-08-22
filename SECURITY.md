# Segurança — Sistema Agêntico n8n WhatsApp+Email

## Modelo de uso

A versão 2.x foi projetada para **execução local em uma máquina confiável**. n8n, WAHA e Ollama são publicados somente em `127.0.0.1` pelo Docker Compose. O projeto não deve ser exposto diretamente à internet sem autenticação adicional, HTTPS, firewall e revisão do modelo de ameaça.

O instalador visual também escuta somente em:

```text
127.0.0.1:8765
```

Ele não foi projetado como painel remoto.

## Human-in-the-loop obrigatório

Duas ferramentas possuem efeito destrutivo ou comunicação externa e são tratadas como operações críticas:

- `apagar_email(id)`;
- `enviar_whatsapp(contato, msg)`.

Essas tools chamam um subfluxo que:

1. registra a solicitação;
2. envia uma notificação ao endereço `APPROVAL_EMAIL`;
3. pausa em um nó `Wait`;
4. somente executa o efeito após aprovação humana explícita;
5. registra aprovação, rejeição e resultado.

O prompt do agente não substitui esse controle técnico: mesmo que a LLM solicite a ação, o caminho de execução permanece bloqueado pelo gate humano.

## Segredos e credenciais

### `.env`

- `.env` permanece fora do Git;
- `.env.example` contém somente placeholders/campos vazios;
- senha PostgreSQL, chave de criptografia n8n, API key WAHA e senha WAHA são geradas localmente;
- Google Client ID/Secret, quando informados no wizard, ficam apenas no `.env` local;
- nenhum `.env` real deve ser compartilhado em issue, commit ou screenshot.

### Senha do proprietário n8n

A senha escolhida na primeira tela do instalador:

- é transmitida somente ao servidor de setup em `127.0.0.1`;
- fica em memória no processo PowerShell apenas durante a instalação;
- é enviada ao endpoint local oficial de criação do proprietário n8n;
- **não é escrita no `.env`**;
- **não é gravada em arquivo temporário pelo instalador**;
- é descartada quando o wizard termina.

O hash e a autenticação posteriores ficam sob responsabilidade do próprio n8n.

### Arquivos temporários de importação

A fase de finalização pode criar:

```text
setup/credentials.runtime.json
setup/workflow.runtime.json
```

Eles existem para que a CLI do n8n receba credenciais e referências do workflow. Como podem conter Client Secret Google:

- estão no `.gitignore`;
- a pasta é montada como somente leitura dentro do container n8n;
- os arquivos são removidos em bloco `finally` após sucesso ou falha da finalização;
- não devem ser copiados para relatórios ou anexos.

### OAuth

- Gmail e Google Calendar usam OAuth2;
- Client ID/Secret podem ser preparados pelo wizard;
- o consentimento da conta continua sendo feito pelo usuário no Google;
- tokens OAuth ficam no armazenamento criptografado do n8n, protegido por `N8N_ENCRYPTION_KEY`;
- o instalador não versiona tokens OAuth.

### WhatsApp / WAHA

- WAHA usa API key e senha de dashboard geradas localmente;
- o pareamento depende de QR Code do proprietário;
- sessão, cookies e QR Code não devem ser publicados;
- o wizard apenas exibe as credenciais locais necessárias para abrir o dashboard.

## Cabeçalhos do wizard

O servidor local do instalador envia, entre outros:

- `Cache-Control: no-store`;
- `X-Content-Type-Options: nosniff`;
- política CSP restritiva para a página local.

Essas medidas reduzem armazenamento acidental no navegador e carregamento desnecessário de recursos externos, mas não transformam o wizard em uma interface destinada à internet.

## Auditoria sem cadeia de pensamento

O projeto registra informações observáveis úteis para investigação e QA:

- input do usuário;
- execution ID;
- tool escolhida;
- argumentos da tool;
- resultado/observação retornado;
- resumo de decisão em alto nível;
- status de aprovação humana;
- output final.

**Não é armazenada cadeia de pensamento privada/raw chain-of-thought.** Rastreabilidade operacional deve se basear em eventos, parâmetros e resultados verificáveis.

## PostgreSQL e histórico

O PostgreSQL persiste estado e histórico das execuções n8n. Isso é especialmente relevante para workflows em estado `Waiting`.

Recomendações:

- backup periódico do volume `postgres_data`;
- não compartilhar dumps sem sanitização;
- definir política de retenção adequada ao ambiente;
- remover dados pessoais de evidências usadas em portfólio.

## WhatsApp e ambiente empresarial

WAHA automatiza WhatsApp Web e não é a API oficial WhatsApp Business. O uso pode estar sujeito a limitações, mudanças de plataforma ou bloqueios. Para uso empresarial em produção, avalie a API oficial e os termos aplicáveis.

## Antes de qualquer exposição externa

Implemente pelo menos:

1. reverse proxy HTTPS;
2. autenticação forte e MFA no n8n quando aplicável;
3. firewall e allowlist de origem;
4. rotação de segredos;
5. proteção do webhook;
6. backup/restore testado;
7. segregação de credenciais por ambiente;
8. monitoramento e alertas;
9. política de retenção de execution data;
10. revisão de privacidade/LGPD conforme o caso de uso.

## Relato de vulnerabilidade

Não publique segredos ou dados pessoais em issues públicas. Ao relatar um problema, forneça passos de reprodução e logs sanitizados, removendo e-mails, telefones, tokens, IDs privados e conteúdo de mensagens.
