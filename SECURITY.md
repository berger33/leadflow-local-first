# Segurança — Sistema Agêntico n8n WhatsApp+Email

## Modelo de uso

A versão 2.x foi projetada para **execução local em uma máquina confiável**. n8n, WAHA e Ollama são publicados somente em `127.0.0.1` pelo Docker Compose. O projeto não deve ser exposto diretamente à internet sem autenticação adicional, HTTPS, firewall e revisão do modelo de ameaça.

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

- `.env` permanece fora do Git;
- `.env.example` contém somente placeholders;
- Gmail e Google Calendar usam OAuth2 configurado no próprio n8n;
- tokens OAuth ficam no armazenamento criptografado do n8n protegido por `N8N_ENCRYPTION_KEY`;
- WAHA usa API key e senha de dashboard;
- PostgreSQL usa senha exclusiva;
- nenhuma chave, cookie, QR code ou token deve ser incluído em commits, issues ou screenshots públicos.

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

O banco PostgreSQL persiste o estado do n8n e o histórico das execuções. Isso é particularmente importante para fluxos em estado `Waiting`, que precisam sobreviver à pausa até a aprovação/rejeição.

Recomendações:

- backup periódico do volume `postgres_data`;
- não compartilhar dumps sem sanitização;
- definir política de retenção adequada ao ambiente;
- remover dados pessoais de evidências usadas em portfólio.

## WhatsApp

WAHA automatiza WhatsApp Web e não é a API oficial WhatsApp Business. O uso pode estar sujeito a limitações, mudanças da plataforma ou bloqueios. Para uso empresarial em produção, avalie a API oficial e os termos aplicáveis.

## Antes de qualquer exposição externa

Implemente pelo menos:

1. reverse proxy HTTPS;
2. autenticação forte e MFA no n8n quando aplicável;
3. firewall e allowlist de origem;
4. rotação de todos os segredos;
5. proteção do webhook WAHA;
6. política de backup e restore testado;
7. segregação de credenciais por ambiente;
8. monitoramento e alertas;
9. política de retenção de execution data;
10. revisão de privacidade/LGPD conforme o caso de uso.

## Relato de vulnerabilidade

Não publique segredos ou dados pessoais em issues públicas. Ao relatar um problema, forneça passos de reprodução e logs sanitizados, removendo e-mails, telefones, tokens, IDs privados e conteúdo de mensagens.
