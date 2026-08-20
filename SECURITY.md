# Segurança

## Escopo suportado

A versão 1.x do LeadFlow foi projetada para **uso local/pessoal em uma máquina ou rede confiável**. Não é uma aplicação SaaS preparada para exposição direta à internet.

## Princípios do projeto

- segredos e credenciais ficam em `.env` ou no armazenamento criptografado do n8n;
- `.env` é ignorado pelo Git;
- WAHA exige API key e senha do dashboard;
- grupos do WhatsApp são ignorados por padrão;
- uma allowlist opcional pode limitar quais chats usam o assistente;
- memória de conversa fica no SQLite local;
- a inferência da LLM ocorre no Ollama local;
- credenciais Gmail nunca são incluídas no repositório.

## Antes de expor qualquer serviço fora de localhost

Implemente, no mínimo:

1. reverse proxy com HTTPS;
2. firewall e restrição de origem;
3. autenticação adicional na API do Assistente;
4. proteção do painel n8n e WAHA;
5. rotação de segredos;
6. política de backups;
7. atualização periódica das imagens Docker;
8. revisão dos termos aplicáveis ao uso de automação de WhatsApp.

## Relatando um problema

Não publique chaves, cookies, QR codes, tokens OAuth, números privados ou dumps de banco em issues públicas. Ao reportar uma falha, remova informações pessoais e segredos dos logs antes de compartilhá-los.

## Dependências de terceiros

O repositório contém código próprio sob licença MIT, mas utiliza projetos e serviços independentes — incluindo Ollama, n8n, WAHA e bibliotecas Python — que possuem suas próprias licenças, políticas e termos de uso.
