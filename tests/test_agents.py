import json
import pytest

from app.agents import DualAgentService, parse_web_command, should_use_web
from app.config import Settings
from app.memory import ConversationMemory
from app.schemas import Source


class FakeLLM:
    def __init__(self):
        self.calls = []

    async def chat(self, model, messages, *, temperature=0.2, json_mode=False):
        self.calls.append({'model': model, 'messages': messages, 'json_mode': json_mode})
        if json_mode:
            return json.dumps({'approved': True, 'score': 0.95, 'issues': [], 'corrected_answer': ''})
        return 'Resposta do primeiro agente [1].'


class FakeSearch:
    def __init__(self):
        self.last_query = None

    async def search_text(self, query, limit=8, timelimit=None):
        self.last_query = query
        return [Source(title='Fonte A', url='https://example.com/a', snippet='Contexto atual')]

    async def search_news(self, query, limit=10, timelimit='d'):
        return [Source(title='Notícia A', url='https://example.com/news', snippet='Notícia quente', source='Exemplo')]


@pytest.fixture
def service(tmp_path):
    settings = Settings(database_path=str(tmp_path / 'memory.db'), ollama_model='model-main', ollama_validator_model='model-validator')
    return DualAgentService(settings, FakeLLM(), FakeSearch(), ConversationMemory(settings.database_path, turns=4))


def test_detects_current_information_need():
    assert should_use_web('Quais são as notícias de tecnologia de hoje?') is True
    assert should_use_web('Explique o que é uma API REST') is False


def test_explicit_web_and_local_commands():
    assert parse_web_command('/web preço do dólar') == ('preço do dólar', True)
    assert parse_web_command('/local explique recursão') == ('explique recursão', False)
    assert parse_web_command('explique recursão') == ('explique recursão', None)


@pytest.mark.asyncio
async def test_second_agent_validates_first_answer(service):
    response = await service.answer('Explique o que é Docker', 'test-chat', use_web=False)
    assert response.answer.startswith('Resposta do primeiro agente')
    assert response.validation.approved is True
    assert response.validation.score == pytest.approx(0.95)
    assert service.llm.calls[-1]['model'] == 'model-validator'
    assert service.llm.calls[-1]['json_mode'] is True


@pytest.mark.asyncio
async def test_web_answer_includes_sources(service):
    response = await service.answer('O que aconteceu hoje em tecnologia?', 'test-chat', use_web=None)
    assert response.used_web is True
    assert len(response.sources) == 1
    assert response.sources[0].url == 'https://example.com/a'


@pytest.mark.asyncio
async def test_web_command_forces_search_and_is_not_sent_as_query(service):
    response = await service.answer('/web quem venceu o jogo?', 'test-chat')
    assert response.used_web is True
    assert service.search.last_query == 'quem venceu o jogo?'


@pytest.mark.asyncio
async def test_local_command_disables_automatic_search(service):
    response = await service.answer('/local notícias de hoje', 'test-chat')
    assert response.used_web is False


@pytest.mark.asyncio
async def test_research_generates_email_ready_report(service):
    response = await service.research('10 notícias de tecnologia', limit=10, kind='news')
    assert 'LeadFlow Research' in response.title
    assert 'https://example.com/news' in response.report_html
    assert response.validation.approved is True
