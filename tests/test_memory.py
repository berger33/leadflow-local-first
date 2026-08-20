from app.memory import ConversationMemory


def test_memory_persists_and_limits_history(tmp_path):
    db = tmp_path / 'leadflow.db'
    memory = ConversationMemory(str(db), turns=2)
    for i in range(8):
        memory.add('chat', 'user' if i % 2 == 0 else 'assistant', f'msg {i}')
    recent = memory.recent('chat')
    assert len(recent) <= 4
    assert recent[-1]['content'] == 'msg 7'
