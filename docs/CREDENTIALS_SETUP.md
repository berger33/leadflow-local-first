# Configuração de acessos — assistente visual

A experiência recomendada não exige editar `.env` nem criar manualmente a conexão Ollama no n8n.

Execute:

```text
INSTALAR_WINDOWS.bat
```

ou, na primeira execução:

```text
INICIAR_WINDOWS.bat
```

O navegador abre o assistente local em:

```text
http://127.0.0.1:8765
```

## O que aparece na primeira tela

### Acesso local do n8n

Informe:

- nome;
- sobrenome;
- e-mail de login;
- senha local.

A senha precisa ter de 8 a 64 caracteres, ao menos uma letra maiúscula e um número.

O assistente utiliza a API local oficial de setup do n8n para criar o primeiro proprietário quando a instância ainda está nova.

**A senha do proprietário não é gravada no `.env` nem em arquivo temporário.** Ela fica somente em memória no processo do assistente durante a instalação.

### Human-in-the-loop

Informe o endereço que receberá pedidos de aprovação antes de:

- `apagar_email`;
- `enviar_whatsapp`.

Esse campo pode ser deixado vazio enquanto você testa somente caminhos não destrutivos.

### Modelos locais

Escolha o modelo do Agente Executor e do Agente QA.

O bootstrap:

1. inicia Ollama;
2. verifica se o modelo já existe;
3. baixa o modelo ausente com até três tentativas;
4. valida com `ollama show`;
5. cria automaticamente no n8n a credencial **Ollama Local - Sistema Agentico**;
6. vincula a credencial aos dois nós de modelo durante a importação do workflow.

Base URL interna:

```text
http://ollama:11434
```

Na instalação padrão do Ollama não é necessária API key.

## Google OAuth2 — Gmail e Calendar

A tela possui campos opcionais para:

```text
Google Client ID
Google Client Secret
```

Para usar a configuração assistida:

1. abra o Google Cloud Console;
2. habilite **Gmail API** e **Google Calendar API**;
3. crie um cliente OAuth 2.0 do tipo **Web application**;
4. cadastre exatamente esta URI de redirecionamento:

```text
http://localhost:5678/rest/oauth2-credential/callback
```

5. copie Client ID e Client Secret para o assistente visual;
6. inicie a instalação.

Quando as duas chaves são informadas, o bootstrap prepara automaticamente:

- credencial `Gmail - Sistema Agentico`;
- credencial `Google Calendar - Sistema Agentico`;
- referências das credenciais nos nós correspondentes do workflow.

Depois da instalação, abra **Credentials** no n8n e conclua o botão de autorização/Sign in with Google.

Esse último consentimento não é automatizado porque pertence à identidade da conta Google.

### Se eu não quiser configurar Google agora?

Deixe Client ID e Client Secret vazios.

PostgreSQL, Ollama, n8n, WAHA e o workflow continuam sendo instalados. Gmail e Calendar podem ser conectados depois.

## WhatsApp / WAHA

O assistente gera automaticamente:

- API key local do WAHA;
- usuário do dashboard;
- senha forte do dashboard;
- configuração do webhook para o n8n.

Na etapa **Conexões**, a interface mostra o usuário e a senha com botões de copiar/revelar.

Abra:

```text
http://127.0.0.1:3000/dashboard
```

Depois inicie a sessão `default` e escaneie o QR Code com o WhatsApp que deseja conectar.

O QR Code é obrigatório porque representa autorização da conta real do usuário.

## Segredos internos

O usuário não precisa inventar nem preencher:

- senha PostgreSQL;
- `N8N_ENCRYPTION_KEY`;
- `WAHA_API_KEY`;
- senha do dashboard WAHA.

Todos são gerados automaticamente e ficam apenas no `.env` local, que está no `.gitignore`.

## Arquivos temporários de configuração

Para importar credenciais e vincular o workflow, o bootstrap cria temporariamente:

```text
setup/credentials.runtime.json
setup/workflow.runtime.json
```

Esses arquivos:

- são ignorados pelo Git;
- existem somente durante a finalização;
- são removidos em bloco `finally`, inclusive quando ocorre falha.

## Fluxo resumido

```text
Preencher uma tela
      ↓
Docker + segredos internos
      ↓
PostgreSQL + Ollama
      ↓
modelo local
      ↓
n8n + WAHA
      ↓
criar proprietário n8n
      ↓
criar credencial Ollama
      ↓
preparar Gmail/Calendar se chaves foram fornecidas
      ↓
importar workflow com referências
      ↓
usuário autoriza Google e escaneia QR do WhatsApp
```

## Ordem segura para validar o sistema

1. faça login no n8n com o acesso escolhido no assistente;
2. use o **Chat de Teste** com uma pergunta que não exige ferramenta externa;
3. se configurou Google, conclua o OAuth;
4. teste `ler_email`;
5. teste `resumir_email`;
6. crie um evento descartável no Calendar;
7. solicite `apagar_email` e primeiro **rejeite** a aprovação;
8. conecte WhatsApp e solicite envio para o próprio número, rejeitando primeiro;
9. confirme que as ações críticas não aconteceram sem autorização;
10. só depois valide caminhos aprovados e uso cotidiano.

Consulte também [`QA_TEST_PLAN.md`](QA_TEST_PLAN.md).
