from functools import lru_cache
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file='.env', extra='ignore', case_sensitive=False)

    app_name: str = 'LeadFlow Local-First'
    assistant_name: str = 'LeadFlow'
    app_env: str = 'production'
    log_level: str = 'INFO'

    ollama_base_url: str = 'http://ollama:11434'
    ollama_model: str = 'qwen3:4b'
    ollama_validator_model: str = 'qwen3:4b'
    ollama_timeout_seconds: float = 180.0

    web_search_region: str = 'br-pt'
    web_search_safesearch: str = 'moderate'
    web_search_max_results: int = 10
    web_search_timeout_seconds: float = 12.0

    database_path: str = '/data/leadflow.db'
    memory_turns: int = 8

    waha_base_url: str = 'http://waha:3000'
    waha_api_key: str = ''
    waha_session: str = 'default'
    whatsapp_allowed_chat_ids: str = ''
    whatsapp_reply_groups: bool = False
    whatsapp_max_reply_chars: int = 3800

    validator_min_score: float = 0.72

    def allowed_chat_ids(self) -> set[str]:
        return {
            item.strip()
            for item in self.whatsapp_allowed_chat_ids.split(',')
            if item.strip()
        }


@lru_cache
def get_settings() -> Settings:
    return Settings()
