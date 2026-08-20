import logging

from fastapi import BackgroundTasks, FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse

from .agents import DualAgentService
from .config import get_settings
from .memory import ConversationMemory
from .ollama_client import OllamaClient, OllamaError
from .schemas import ChatRequest, ChatResponse, ResearchRequest, ResearchResponse, WahaWebhookAck
from .search import SearchError, WebSearch
from .waha import WahaClient, extract_message_event

settings = get_settings()
logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))
logger = logging.getLogger('leadflow')

llm = OllamaClient(settings.ollama_base_url, settings.ollama_timeout_seconds)
search = WebSearch(settings.web_search_region, settings.web_search_safesearch, settings.web_search_timeout_seconds)
memory = ConversationMemory(settings.database_path, settings.memory_turns)
agent = DualAgentService(settings, llm, search, memory)
waha = WahaClient(settings.waha_base_url, settings.waha_api_key, settings.waha_session)

app = FastAPI(
    title='LeadFlow Local-First API',
    version='1.0.0',
    description='Assistente local com pesquisa web, validação por segundo agente e integração WhatsApp/n8n.',
)


@app.get('/')
async def root():
    return {
        'name': settings.app_name,
        'status': 'ready',
        'docs': '/docs',
        'health': '/health',
    }


@app.get('/health')
async def health():
    ollama = await llm.health()
    return {
        'status': 'ok' if ollama['ok'] else 'degraded',
        'ollama': ollama,
        'model': settings.ollama_model,
        'validator_model': settings.ollama_validator_model,
    }


@app.post('/chat', response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        return await agent.answer(request.message, request.chat_id, request.use_web)
    except OllamaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


@app.post('/research', response_model=ResearchResponse)
async def research(request: ResearchRequest):
    try:
        return await agent.research(
            request.query,
            limit=request.limit,
            kind=request.kind,
            timelimit=request.timelimit,
            language=request.language,
        )
    except SearchError as exc:
        raise HTTPException(status_code=502, detail=str(exc)) from exc
    except OllamaError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc


async def _process_whatsapp(chat_id: str, text: str):
    try:
        response = await agent.answer(text, chat_id)
        answer = response.answer[: settings.whatsapp_max_reply_chars]
        if response.sources:
            refs = '\n\nFontes:\n' + '\n'.join(
                f'{idx}. {source.url}' for idx, source in enumerate(response.sources[:5], 1)
            )
            if len(answer) + len(refs) <= settings.whatsapp_max_reply_chars:
                answer += refs
        await waha.send_text(chat_id, answer)
    except Exception:
        logger.exception('Falha ao processar mensagem do WhatsApp para %s', chat_id)
        try:
            await waha.send_text(chat_id, 'Não consegui processar sua mensagem agora. Tente novamente em alguns instantes.')
        except Exception:
            logger.exception('Também falhou o envio da mensagem de erro ao WhatsApp')


@app.post('/webhooks/waha', response_model=WahaWebhookAck)
async def waha_webhook(request: Request, background_tasks: BackgroundTasks):
    payload = await request.json()
    chat_id, text, from_me = extract_message_event(payload)
    if from_me:
        return WahaWebhookAck(status='ignored', reason='message_from_self')
    if not chat_id or not text or not text.strip():
        return WahaWebhookAck(status='ignored', reason='not_a_text_message')
    if chat_id.endswith('@g.us') and not settings.whatsapp_reply_groups:
        return WahaWebhookAck(status='ignored', reason='group_messages_disabled')
    allowlist = settings.allowed_chat_ids()
    if allowlist and chat_id not in allowlist:
        return WahaWebhookAck(status='ignored', reason='chat_not_allowed')
    background_tasks.add_task(_process_whatsapp, chat_id, text.strip())
    return WahaWebhookAck(status='accepted')


@app.exception_handler(Exception)
async def unhandled_error(_: Request, exc: Exception):
    logger.exception('Erro não tratado: %s', exc)
    return JSONResponse(status_code=500, content={'detail': 'Erro interno do LeadFlow.'})
