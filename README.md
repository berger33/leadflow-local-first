# LeadFlow Local-First

Protótipo de infraestrutura para estudar **automação de atendimento com IA executada localmente**, combinando uma API de WhatsApp e modelos locais em containers Docker.

> **Status:** protótipo em evolução. Este repositório representa a camada de infraestrutura inicial, não um produto final.

## Objetivo

Explorar uma arquitetura em que mensagens possam ser integradas a fluxos de automação e modelos de linguagem mantendo o máximo possível do processamento sob controle local.

## Arquitetura atual

```text
WhatsApp
   |
   v
WAHA API
   |
   +---- futura camada de aplicação / automação
   |
   v
Ollama
   |
   v
Modelo local
```

## Tecnologias

- **Docker Compose** — orquestração dos serviços
- **WAHA** — API para integração com WhatsApp
- **Ollama** — execução local de modelos de linguagem

## Requisitos

- Docker
- Docker Compose

## Como executar

1. Clone o repositório:

```bash
git clone https://github.com/berger33/leadflow-local-first.git
cd leadflow-local-first
```

2. Crie o arquivo de ambiente a partir do exemplo:

### Linux/macOS

```bash
cp .env.example .env
```

### Windows (PowerShell)

```powershell
Copy-Item .env.example .env
```

3. Edite `.env` e defina uma chave segura para `WHATSAPP_API_KEY`.

4. Inicie os serviços:

```bash
docker compose up -d
```

5. Verifique os containers:

```bash
docker compose ps
```

## Portas locais

| Serviço | Porta |
| --- | ---: |
| WAHA | `3000` |
| Ollama | `11434` |

## Segurança

Credenciais não ficam gravadas no `docker-compose.yml`. A chave da API é lida do arquivo `.env`, que está ignorado pelo Git. O repositório fornece somente `.env.example` com um valor de demonstração.

## Próximas etapas

- criar uma camada de aplicação entre WAHA e Ollama;
- definir persistência para contatos, conversas e estado;
- adicionar health checks dos serviços;
- implementar testes de integração;
- documentar um fluxo completo de mensagem → processamento → resposta;
- avaliar autenticação, observabilidade e limites de uso.

## Por que este projeto existe

Este repositório faz parte dos meus estudos em **IA aplicada, automação, integração entre serviços e arquiteturas local-first**. A intenção é evoluí-lo de uma composição de infraestrutura para uma aplicação completa e reproduzível.
