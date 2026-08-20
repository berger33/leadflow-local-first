import asyncio

from .schemas import Source


class SearchError(RuntimeError):
    pass


class WebSearch:
    def __init__(self, region: str = 'br-pt', safesearch: str = 'moderate', timeout: float = 12.0):
        self.region = region
        self.safesearch = safesearch
        self.timeout = timeout

    async def search_text(self, query: str, limit: int = 8, timelimit: str | None = None) -> list[Source]:
        return await asyncio.to_thread(self._text_sync, query, limit, timelimit)

    async def search_news(self, query: str, limit: int = 10, timelimit: str | None = 'd') -> list[Source]:
        return await asyncio.to_thread(self._news_sync, query, limit, timelimit)

    def _client(self):
        try:
            from ddgs import DDGS
        except ImportError as exc:
            raise SearchError('Dependência de pesquisa DDGS não está instalada.') from exc
        return DDGS(timeout=int(self.timeout))

    def _text_sync(self, query: str, limit: int, timelimit: str | None) -> list[Source]:
        try:
            rows = self._client().text(
                query,
                region=self.region,
                safesearch=self.safesearch,
                timelimit=timelimit,
                max_results=limit,
            )
        except Exception as exc:
            raise SearchError(f'Falha na pesquisa web: {exc}') from exc
        return [
            Source(
                title=row.get('title', '').strip() or 'Resultado sem título',
                url=row.get('href', '').strip(),
                snippet=row.get('body', '').strip(),
            )
            for row in rows
            if row.get('href')
        ]

    def _news_sync(self, query: str, limit: int, timelimit: str | None) -> list[Source]:
        try:
            rows = self._client().news(
                query,
                region=self.region,
                safesearch=self.safesearch,
                timelimit=timelimit,
                max_results=limit,
            )
        except Exception as exc:
            raise SearchError(f'Falha na pesquisa de notícias: {exc}') from exc
        return [
            Source(
                title=row.get('title', '').strip() or 'Notícia sem título',
                url=row.get('url', '').strip(),
                snippet=row.get('body', '').strip(),
                published=row.get('date'),
                source=row.get('source'),
            )
            for row in rows
            if row.get('url')
        ]
