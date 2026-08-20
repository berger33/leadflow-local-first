import html
import json
import re
from datetime import datetime, timezone

from .config import Settings
from .memory import ConversationMemory
from .ollama_client import OllamaClient
from .schemas import ChatResponse, ResearchResponse, Source, ValidationResult
from .search import WebSearch, SearchError

WEB_HINTS = {
    'hoje', 'agora', 'atual', 'atuais', 'atualizado', 'atualizada', 'última', 'últimas', 'ultimo',
    'último', 'recentes', 'recente', 'notícia', 'noticias', 'notícias', 'preço', 'cotação', 'clima',
    'resultado', 'placar', 'lançamento', 'lançamentos', 'pesquise', 'pesquisar', 'internet', 'web',
    'fonte', 'fontes', 'aconteceu', 'acontecendo', 'tendência', 'tendencias', 'tendências'
}


def should_use_web(message: str) -> bool:
    normalized = re.sub(r'[^\wÀ-ÿ]+', ' ', message.lower())
    tokens = set(normalized.split())
    return bool(tokens & WEB_HINTS)


def parse_web_command(message: str) -> tuple[str, bool | None]:
    """Remove comandos opcionais /web e /local usados no WhatsApp/API."""
    stripped = message.strip()
    lowered = stripped.lower()
    for prefix, web in (('/web', True), ('/local', False)):
        if lowered == prefix:
            return stripped, web
        if lowered.startswith(prefix + ' ') or lowered.startswith(prefix + ':'):
            cleaned = stripped[len(prefix):].lstrip(' :')
            return cleaned or stripped, web
    return stripped, None


def _sources_context(sources: list[Source]) -> str:
    if not sources:
        return ''
    lines = []
    for idx, source in enumerate(sources, 1):
        published = f' | data: {source.published}' if source.published else ''
        publisher = f' | fonte: {source.source}' if source.source else ''
        lines.append(
            f'[{idx}] {source.title}{published}{publisher}\nURL: {source.url}\nResumo do buscador: {source.snippet}'
        )
    return '\n\n'.join(lines)


def _parse_validation(raw: str, draft: str) -> ValidationResult:
    raw = raw.strip()
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        match = re.search(r'\{.*\}', raw, flags=re.S)
        if not match:
            return ValidationResult(
                approved=True,
                score=0.75,
                issues=['Validador retornou formato não estruturado; resposta original preservada.'],
                corrected_answer=draft,
            )
        try:
            data = json.loads(match.group(0))
        except json.JSONDecodeError:
            return ValidationResult(
                approved=True,
                score=0.75,
                issues=['Validador retornou JSON inválido; resposta original preservada.'],
                corrected_answer=draft,
            )

    score = float(data.get('score', 0.0) or 0.0)
    score = max(0.0, min(score, 1.0))
    approved = bool(data.get('approved', False))
    issues = data.get('issues') or []
    if not isinstance(issues, list):
        issues = [str(issues)]
    corrected = (data.get('corrected_answer') or '').strip()
    return ValidationResult(
        approved=approved,
        score=score,
        issues=[str(i) for i in issues[:8]],
        corrected_answer=corrected or draft,
    )


class DualAgentService:
    def __init__(
        self,
        settings: Settings,
        llm: OllamaClient,
        search: WebSearch,
        memory: ConversationMemory,
    ):
        self.settings = settings
        self.llm = llm
        self.search = search
        self.memory = memory

    async def _validate(self, question: str, draft: str, sources: list[Source]) -> ValidationResult:
        source_context = _sources_context(sources)
        system = (
            'Você é o Agente Validador do LeadFlow. Sua tarefa é revisar a resposta de outro agente. '
            'Avalie se ele entendeu exatamente a pergunta, respondeu ao que foi pedido, não inventou fatos, '
            'distinguiu fatos atuais de conhecimento geral e respeitou as fontes quando elas existem. '
            'Retorne SOMENTE JSON válido com: approved (boolean), score (0 a 1), issues (lista de strings) '
            'e corrected_answer (string). Se houver problema, reescreva a resposta em corrected_answer. '
            'Não adicione fatos novos sem suporte nas fontes fornecidas.'
        )
        user = (
            f'PERGUNTA ORIGINAL:\n{question}\n\n'
            f'RESPOSTA DO PRIMEIRO AGENTE:\n{draft}\n\n'
            f'FONTES DISPONÍVEIS:\n{source_context or "Nenhuma fonte web foi usada."}'
        )
        raw = await self.llm.chat(
            self.settings.ollama_validator_model,
            [{'role': 'system', 'content': system}, {'role': 'user', 'content': user}],
            temperature=0.0,
            json_mode=True,
        )
        return _parse_validation(raw, draft)

    async def answer(self, message: str, chat_id: str, use_web: bool | None = None) -> ChatResponse:
        clean_message, command_override = parse_web_command(message)
        if use_web is not None:
            web = use_web
        elif command_override is not None:
            web = command_override
        else:
            web = should_use_web(clean_message)

        sources: list[Source] = []
        if web:
            try:
                sources = await self.search.search_text(
                    clean_message,
                    limit=min(self.settings.web_search_max_results, 8),
                    timelimit='w',
                )
            except SearchError:
                sources = []

        history = self.memory.recent(chat_id)
        system = (
            f'Você é {self.settings.assistant_name}, um assistente pessoal executado localmente. '
            'Responda em português do Brasil por padrão, a menos que o usuário peça outro idioma. '
            'Se houver fontes web, use-as como contexto factual e cite-as no texto como [1], [2] etc. '
            'Nunca afirme que pesquisou a internet se nenhuma fonte foi fornecida. '
            'Se a pergunta for ambígua, responda da forma mais útil possível e diga qual interpretação adotou. '
            'Se não souber, diga claramente que não sabe. Seja objetivo, mas completo.'
        )
        context = _sources_context(sources)
        messages = [{'role': 'system', 'content': system}]
        messages.extend(history)
        if context:
            messages.append({'role': 'system', 'content': f'CONTEXTO WEB ATUAL:\n{context}'})
        messages.append({'role': 'user', 'content': clean_message})

        draft = await self.llm.chat(
            self.settings.ollama_model,
            messages,
            temperature=0.25,
        )
        validation = await self._validate(clean_message, draft, sources)
        final = draft
        if (not validation.approved or validation.score < self.settings.validator_min_score) and validation.corrected_answer:
            final = validation.corrected_answer

        self.memory.add(chat_id, 'user', clean_message)
        self.memory.add(chat_id, 'assistant', final)
        return ChatResponse(
            answer=final,
            used_web=web and bool(sources),
            sources=sources,
            validation=validation,
            model=self.settings.ollama_model,
            validator_model=self.settings.ollama_validator_model,
        )

    async def research(
        self,
        query: str,
        limit: int = 10,
        kind: str = 'news',
        timelimit: str | None = 'd',
        language: str = 'pt-BR',
    ) -> ResearchResponse:
        if kind == 'news':
            sources = await self.search.search_news(query, limit=limit, timelimit=timelimit)
        else:
            sources = await self.search.search_text(query, limit=limit, timelimit=timelimit)
        if not sources:
            raise SearchError('A pesquisa não retornou resultados.')

        context = _sources_context(sources)
        system = (
            'Você é um analista de pesquisa. Produza um relatório factual, útil e escaneável. '
            'Use apenas as fontes fornecidas para afirmações atuais. Cite cada item como [n]. '
            'Não invente datas, números ou fatos. Dê prioridade ao que é realmente relevante e recente.'
        )
        user = (
            f'Consulta: {query}\nIdioma do relatório: {language}\n\n'
            f'Fontes coletadas:\n{context}\n\n'
            'Crie: 1) resumo executivo em até 6 bullets; 2) principais achados em ordem de importância; '
            '3) por que isso importa; 4) lista final de fontes numeradas com título e URL.'
        )
        draft = await self.llm.chat(
            self.settings.ollama_model,
            [{'role': 'system', 'content': system}, {'role': 'user', 'content': user}],
            temperature=0.15,
        )
        validation = await self._validate(query, draft, sources)
        final = draft
        if (not validation.approved or validation.score < self.settings.validator_min_score) and validation.corrected_answer:
            final = validation.corrected_answer

        now = datetime.now(timezone.utc).astimezone()
        title = f'LeadFlow Research — {query[:90]}'
        safe_text = html.escape(final).replace('\n', '<br>')
        source_items = ''.join(
            f'<li><a href="{html.escape(s.url)}">{html.escape(s.title)}</a>'
            f'{" — " + html.escape(s.source) if s.source else ""}</li>'
            for s in sources
        )
        report_html = (
            '<div style="font-family:Arial,sans-serif;line-height:1.55;max-width:900px">'
            f'<h2>{html.escape(title)}</h2>'
            f'<p><small>Gerado em {now.strftime("%d/%m/%Y %H:%M %Z")}</small></p>'
            f'<div>{safe_text}</div><hr><h3>Fontes coletadas</h3><ol>{source_items}</ol>'
            '<p><small>Relatório gerado localmente pelo LeadFlow e revisado por um segundo agente.</small></p>'
            '</div>'
        )
        whatsapp_summary = final[: self.settings.whatsapp_max_reply_chars]
        return ResearchResponse(
            title=title,
            report_text=final,
            report_html=report_html,
            whatsapp_summary=whatsapp_summary,
            sources=sources,
            validation=validation,
            generated_at=now.isoformat(),
        )
