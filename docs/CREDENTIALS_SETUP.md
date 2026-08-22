# Configuração de acessos — primeira execução

O projeto automatiza tudo o que pode ser configurado com segurança sem se passar pelo usuário. Contas externas continuam exigindo consentimento do proprietário.

## O que é automático

Ao executar `INICIAR_WINDOWS.bat`, o bootstrap:

- cria `.env` se necessário;
- gera senhas/chaves internas aleatórias;
- inicia PostgreSQL e Ollama;
- aguarda os serviços ficarem saudáveis;
- verifica se os modelos definidos em `OLLAMA_MODEL` e `OLLAMA_VALIDATOR_MODEL` já existem;
- baixa os modelos ausentes com até três tentativas;
- inicia n8n e WAHA;
- detecta se o n8n ainda precisa criar o primeiro proprietário local;
- aguarda esse cadastro quando necessário;
- importa o workflow principal sem duplicá-lo.

## 1. Proprietário local do n8n

Em uma instalação nova, o n8n exige a criação de um usuário proprietário local.

O bootstrap detecta `showSetupOnFirstLoad`, abre automaticamente:

```text
http://127.0.0.1:5678
```

Preencha o formulário do n8n e volte ao terminal. Ao pressionar `ENTER`, o bootstrap confirma que o cadastro terminou e continua a importação.

Esse acesso é local ao n8n e não é uma chave de API externa.

## 2. Ollama

O modelo é baixado automaticamente. A única configuração restante no editor do n8n é a conexão local exigida pelo próprio tipo de nó Ollama.

Crie uma credencial **Ollama API** com:

```text
Base URL: http://ollama:11434
API Key: deixe vazio
```

Selecione-a em:

- `Ollama · Modelo Executor`;
- `Ollama · Modelo Validador`.

Nenhuma chave paga é necessária para o Ollama local.

## 3. Gmail OAuth2

Gmail é uma conta externa. O n8n precisa que o próprio usuário autorize o acesso via OAuth2.

Conecte uma credencial Gmail e atribua-a aos nós:

- `ler_email`;
- `resumir_email`;
- `Solicitar aprovação · apagar_email`;
- `Gmail · Apagar Email`;
- `Solicitar aprovação · enviar_whatsapp`.

Para os primeiros testes de exclusão, use mensagens sem importância ou uma conta de teste.

## 4. Google Calendar OAuth2

Conecte a conta Google Calendar e selecione-a no nó:

```text
criar_evento
```

Primeiro teste recomendado: criar um evento descartável.

## 5. WhatsApp / WAHA

O bootstrap gera automaticamente a API key e senha local do WAHA no `.env`.

Abra:

```text
http://127.0.0.1:3000/dashboard
```

O pareamento do WhatsApp exige QR Code porque depende do aparelho/conta real do usuário.

1. abra/inicie a sessão `default`;
2. escaneie o QR Code;
3. aguarde a sessão ficar operacional;
4. o webhook para o n8n já vem configurado pelo Compose.

## 6. E-mail de aprovação humana

Na primeira execução, se `APPROVAL_EMAIL` estiver vazio, o bootstrap pergunta qual endereço deverá receber os links de aprovação.

Você pode pressionar `ENTER` para configurar depois enquanto testa somente caminhos não destrutivos.

## Por que OAuth e QR Code não são automatizados silenciosamente?

Porque Gmail, Calendar e WhatsApp representam identidade e autorização do próprio usuário. Guardar tokens, cookies ou sessões reais em um repositório público seria inseguro.

A automação termina exatamente na fronteira onde o consentimento humano precisa começar.

## Ordem segura de validação

1. configure a conexão Ollama;
2. faça uma pergunta simples pelo Chat de Teste;
3. conecte Gmail e teste `ler_email`;
4. teste `resumir_email`;
5. conecte Calendar e crie um evento descartável;
6. solicite `apagar_email` e **rejeite**;
7. pareie o WhatsApp e solicite um envio para seu próprio número, também rejeitando primeiro;
8. confirme que nenhuma ação crítica ocorreu sem aprovação;
9. valide os caminhos aprovados;
10. só depois ative o webhook para uso cotidiano.

Consulte também [`QA_TEST_PLAN.md`](QA_TEST_PLAN.md).
