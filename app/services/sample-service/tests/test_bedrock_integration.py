from unittest import mock

from app import app as flask_app


def test_summarize_endpoint_uses_bedrock(monkeypatch):
    # Patch the bedrock_client.summarize_notes to simulate Bedrock output
    fake = {
        'overall_summary': 'Fake overall',
        'customer_summary': 'Fake customer',
        'adjuster_summary': 'Fake adjuster',
        'recommended_next_step': 'Fake next'
    }

    monkeypatch.setenv('MOCKS_PATH', __import__('os').path.abspath(__import__('os').path.join(__import__('os').path.dirname(__file__), '..', '..', '..')))

    # Importing bedrock_client may fail because boto3 isn't used in this test path; ensure patch target exists
    monkeypatch.setattr('bedrock_client.summarize_notes', lambda notes: fake, raising=False)

    client = flask_app.test_client()
    resp = client.post('/claims/1001/summarize')
    assert resp.status_code == 200
    data = resp.get_json()
    assert data['summary']['overall_summary'] == 'Fake overall'
