# Configuração do Gmail no n8n

O repositório **não contém credenciais Google**. Cada pessoa que baixar o projeto conecta a própria conta no n8n uma única vez.

## Passos

1. Inicie o LeadFlow e abra `http://localhost:5678`.
2. Crie o usuário administrador local do n8n se for a primeira execução.
3. Importe `n8n/workflows/daily-technology-news.json`.
4. Abra o node **Enviar relatório pelo Gmail**.
5. Em **Credential to connect with**, crie uma credencial Gmail OAuth2 e siga o fluxo exibido pelo próprio n8n/Google.
6. Confirme que `GMAIL_REPORT_TO` no `.env` contém o endereço que receberá os relatórios.
7. Execute o workflow manualmente uma vez.
8. Depois de receber o e-mail de teste, ative o workflow.

O node oficial Gmail do n8n suporta envio de mensagens. A autorização fica armazenada no volume local do n8n e protegida pela `N8N_ENCRYPTION_KEY` configurada no `.env`.

## Segurança

- nunca coloque Client Secret, refresh token ou credenciais exportadas no GitHub;
- mantenha o `.env` fora do Git;
- não compartilhe o volume `n8n_data` publicamente;
- para uso fora de localhost, configure HTTPS e revise as recomendações de segurança do n8n.
