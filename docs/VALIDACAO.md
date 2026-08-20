# Validação da versão 1.0

Este documento separa o que foi validado automaticamente do que, por depender das contas pessoais de quem instala, precisa ser concluído na primeira execução.

## Validado no código

A versão 1.0 foi submetida a testes automatizados da lógica de aplicação:

```text
10 passed
```

Cobertura funcional dos testes:

- detecção automática de perguntas que precisam de informação atual da internet;
- comandos explícitos `/web` e `/local` para controlar o uso da internet;
- remoção do comando `/web` antes de enviar a consulta ao buscador;
- execução do Agente 1 e chamada independente do Agente 2 Validador;
- aprovação e score estruturado da validação;
- inclusão de fontes em respostas com pesquisa web;
- geração de relatório de notícias em formato próprio para e-mail;
- interpretação de eventos `message` recebidos da WAHA;
- persistência e limitação da janela de memória SQLite.

Também foram executadas validações estáticas de:

- compilação/importação dos módulos Python;
- sintaxe JSON dos três workflows n8n;
- estrutura do node Gmail conferida contra a implementação atual do node `n8n-nodes-base.gmail` (`resource=message`, `operation=send`, `emailType=html`);
- configuração do projeto preparada para `docker compose config` no CI.

## GitHub Actions

O workflow `.github/workflows/ci.yml` executa em cada push:

1. instalação das dependências;
2. `pytest`;
3. validação JSON dos workflows;
4. validação de sintaxe do Docker Compose.

## O que exige o computador/conta de quem instala

Nenhum repositório público pode entregar previamente estas duas autorizações sem expor credenciais pessoais:

### Pareamento do WhatsApp

A pessoa precisa abrir o dashboard WAHA e escanear o QR Code com o próprio WhatsApp. A sessão fica persistida em volume local depois disso.

### Autorização do Gmail

A pessoa precisa selecionar/criar sua credencial Gmail OAuth2 dentro do n8n. Tokens e credenciais Google não são incluídos no GitHub.

## Checklist de aceitação em uma instalação nova

Depois da primeira configuração:

- [ ] `http://localhost:8000/health` informa `status: ok`;
- [ ] o dashboard WAHA mostra a sessão `default` operacional;
- [ ] uma mensagem privada enviada ao WhatsApp conectado recebe resposta;
- [ ] uma pergunta contendo “hoje”, “notícias”, “pesquise” ou equivalente retorna fontes atuais;
- [ ] `/web sua pergunta` força pesquisa e retorna fontes quando disponíveis;
- [ ] `/local sua pergunta` responde sem consultar a internet;
- [ ] `scripts/test-research.ps1` retorna relatório + fontes + validação;
- [ ] execução manual do workflow diário envia um e-mail ao endereço configurado;
- [ ] após a execução manual bem-sucedida, o workflow pode ser ativado para rodar diariamente.

Esse checklist evita confundir **código validado** com **credenciais externas ainda não autorizadas**.
