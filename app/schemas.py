from typing import Literal
from pydantic import BaseModel, Field


class Source(BaseModel):
    title: str
    url: str
    snippet: str = ''
    published: str | None = None
    source: str | None = None


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=8000)
    chat_id: str = 'api-user'
    use_web: bool | None = None


class ValidationResult(BaseModel):
    approved: bool
    score: float = Field(ge=0, le=1)
    issues: list[str] = []
    corrected_answer: str = ''


class ChatResponse(BaseModel):
    answer: str
    used_web: bool
    sources: list[Source] = []
    validation: ValidationResult
    model: str
    validator_model: str


class ResearchRequest(BaseModel):
    query: str = Field(min_length=2, max_length=1000)
    limit: int = Field(default=10, ge=1, le=20)
    kind: Literal['news', 'text'] = 'news'
    timelimit: Literal['d', 'w', 'm', 'y'] | None = 'd'
    language: str = 'pt-BR'


class ResearchResponse(BaseModel):
    title: str
    report_text: str
    report_html: str
    whatsapp_summary: str
    sources: list[Source]
    validation: ValidationResult
    generated_at: str


class WahaWebhookAck(BaseModel):
    status: Literal['accepted', 'ignored', 'error']
    reason: str | None = None
