from app.waha import extract_message_event


def test_extract_waha_message_event():
    payload = {
        'event': 'message',
        'session': 'default',
        'payload': {'from': '5511999999999@c.us', 'body': 'Olá LeadFlow', 'fromMe': False},
    }
    chat_id, text, from_me = extract_message_event(payload)
    assert chat_id == '5511999999999@c.us'
    assert text == 'Olá LeadFlow'
    assert from_me is False


def test_ignores_non_message_event():
    assert extract_message_event({'event': 'session.status'}) == (None, None, False)
