import sqlite3
import threading
from pathlib import Path


class ConversationMemory:
    def __init__(self, database_path: str, turns: int = 8):
        self.database_path = database_path
        self.turns = max(1, turns)
        self._lock = threading.Lock()
        Path(database_path).parent.mkdir(parents=True, exist_ok=True)
        self._init_db()

    def _connect(self):
        return sqlite3.connect(self.database_path, timeout=10)

    def _init_db(self):
        with self._connect() as con:
            con.execute(
                '''
                CREATE TABLE IF NOT EXISTS messages (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    chat_id TEXT NOT NULL,
                    role TEXT NOT NULL,
                    content TEXT NOT NULL,
                    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
                )
                '''
            )
            con.execute('CREATE INDEX IF NOT EXISTS idx_messages_chat_id ON messages(chat_id, id)')

    def add(self, chat_id: str, role: str, content: str):
        if not chat_id or not content:
            return
        with self._lock, self._connect() as con:
            con.execute(
                'INSERT INTO messages(chat_id, role, content) VALUES (?, ?, ?)',
                (chat_id, role, content[:12000]),
            )
            keep = self.turns * 2 + 4
            con.execute(
                '''
                DELETE FROM messages
                WHERE chat_id = ? AND id NOT IN (
                    SELECT id FROM messages WHERE chat_id = ? ORDER BY id DESC LIMIT ?
                )
                ''',
                (chat_id, chat_id, keep),
            )

    def recent(self, chat_id: str) -> list[dict[str, str]]:
        with self._lock, self._connect() as con:
            rows = con.execute(
                'SELECT role, content FROM messages WHERE chat_id = ? ORDER BY id DESC LIMIT ?',
                (chat_id, self.turns * 2),
            ).fetchall()
        return [
            {'role': role, 'content': content}
            for role, content in reversed(rows)
        ]
