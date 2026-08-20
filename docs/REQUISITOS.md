# Requisitos e dimensionamento

## Requisitos mínimos

- Windows 10/11, Linux ou macOS 64-bit;
- Docker Desktop / Docker Engine com Compose v2;
- 8 GB de RAM no computador;
- aproximadamente 8 GB livres em disco para imagens, modelo e dados;
- conexão à internet para instalação inicial, pesquisas web e Gmail;
- smartphone com WhatsApp para pareamento da sessão.

## Recomendado

- 16 GB de RAM ou mais;
- CPU com 4+ núcleos modernos;
- SSD;
- GPU compatível com Ollama é opcional e melhora bastante a latência.

## Modelo padrão

O `.env.example` usa `qwen3:4b` para resposta e validação. O modelo é configurável.

Em hardware mais limitado, troque os dois valores por um modelo menor disponível no Ollama. Em hardware mais forte, use modelos maiores para melhorar qualidade.

## O que continua local

- inferência da LLM;
- memória das conversas;
- sessão WAHA;
- workflows e credenciais n8n;
- dados operacionais do assistente.

## O que acessa a internet

- pesquisa web solicitada pelo usuário ou pelos workflows;
- download inicial de imagens Docker e modelos Ollama;
- WhatsApp Web por meio da WAHA;
- Gmail quando o workflow envia relatórios.
