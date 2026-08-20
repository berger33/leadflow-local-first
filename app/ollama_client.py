import json
import httpx


class OllamaError(RuntimeError):
    pass


class OllamaClient:
    def __init__(self, base_url: str, timeout: float = 180.0):
        self.base_url = base_url.rstrip('/')
        self.timeout = timeout

    async def chat(
        self,
        model: str,
        messages: list[dict[str, str]],
        *,
        temperature: float = 0.2,
        json_mode: bool = False,
    ) -> str:
        payload = {
            'model': model,
            'messages': messages,
            'stream': False,
            'options': {'temperature': temperature},
        }
        if json_mode:
            payload['format'] = 'json'
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(f'{self.base_url}/api/chat', json=payload)
                response.raise_for_status()
                data = response.json()
        except (httpx.HTTPError, json.JSONDecodeError, KeyError) as exc:
            raise OllamaError(f'Falha ao consultar o Ollama: {exc}') from exc

        try:
            return data['message']['content'].strip()
        except (KeyError, TypeError, AttributeError) as exc:
            raise OllamaError('Resposta inesperada do Ollama') from exc

    async def health(self) -> dict:
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f'{self.base_url}/api/tags')
                response.raise_for_status()
                data = response.json()
            return {'ok': True, 'models': [m.get('name') for m in data.get('models', [])]}
        except Exception as exc:
            return {'ok': False, 'error': str(exc), 'models': []}
