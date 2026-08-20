import httpx


class WahaClient:
    def __init__(self, base_url: str, api_key: str, session: str = 'default'):
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.session = session

    async def send_text(self, chat_id: str, text: str):
        headers = {'Content-Type': 'application/json'}
        if self.api_key:
            headers['X-Api-Key'] = self.api_key
        payload = {'session': self.session, 'chatId': chat_id, 'text': text}
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(f'{self.base_url}/api/sendText', json=payload, headers=headers)
            response.raise_for_status()
            return response.json()


def extract_message_event(payload: dict) -> tuple[str | None, str | None, bool]:
    if payload.get('event') != 'message':
        return None, None, False
    data = payload.get('payload') or {}
    from_me = bool(data.get('fromMe')) or bool((data.get('_data') or {}).get('id', {}).get('fromMe'))
    chat_id = data.get('from') or data.get('chatId')
    text = data.get('body') or data.get('text')
    if not chat_id and isinstance(data.get('id'), str):
        parts = data['id'].split('_')
        if len(parts) > 1:
            chat_id = parts[1]
    return chat_id, text, from_me
